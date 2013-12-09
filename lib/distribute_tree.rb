# encoding: UTF-8

require 'mongoid'
require 'resque'

module ::Mongoid
  module DistributeTree
    extend ActiveSupport::Concern
    mattr_accessor :default_queue, :default_distribute_urls_proc, :is_allowed_model_proc
    self.default_distribute_urls_proc = -> {}
    self.is_allowed_model_proc = lambda {|model = nil| return false }

    included do
      @queue = Mongoid::DistributeTree.default_queue

      # 配置和回调
      cattr_accessor :distribute_children
      self.distribute_children ||= []

      # 是否该平台上分发
      if Mongoid::DistributeTree.is_allowed_model_proc.call(self)
        after_save     :distribute_without_children
        after_destroy  :distribute_without_children
      end if $IS_CLOUD_SERVER # 目前只在cloud上有
    end

    # 不递归 和 递归 两种
    def distribute_without_children distribute_urls = nil; Utils.distribute self, distribute_urls, false end
    def distribute_with_children    distribute_urls = nil; Utils.distribute self, distribute_urls, true  end

    module Utils
      def self.distribute item, distribute_urls, is_with_children
        # embedded_in已经被父级同步
        return false if item.class.relations.detect {|k, v| v.macro == :embedded_in }

        # 分发到各URL
        distribute_urls = Mongoid::DistributeTree.default_distribute_urls_proc.call if distribute_urls.nil?
        distribute_urls = Array(distribute_urls).flatten.compact
        distribute_urls.map do |_distribute_url|
          Resque.enqueue item.class, item.uuid, _distribute_url, is_with_children
          DistributeTreeStatus.insert item.class, item.uuid, _distribute_url
        end
      end
    end

    module ClassMethods
      DeleteCallback = proc do |item_class, item_uuid, server_url|
        DistributeTreeStatus.delete item_class, item_uuid, server_url
      end

      def perform _uuid, _distribute_url, is_with_children = false
        klass = self
        # 兼容 被删除 或者 软删除
        item = (klass.respond_to?(:unscoped) ? klass.unscoped : klass).uuid(_uuid)
        is_deleted = item.nil? || (item.respond_to?(:deleted?) && item.deleted?)

        # sync data structure
        payload = {
          model_name: klass.name,
          model: is_deleted ? {uuid: _uuid, delete: true} : item.as_json
        }

        # sync json
        # RestClient.put "#{_distribute_url}/upload/warpgate", {:payload => payload}
        # 会导致把app_versions解释为单个对象的Hash。
        Rails.logger.info "[DistributeTree] begin sync #{klass}[#{item.uuid}] json at #{Time.now}"
        RestClient.put "#{_distribute_url}/upload/warpgate.json", {:payload => payload}.to_json,  {:content_type => :json}
        Rails.logger.info "[DistributeTree] end   sync #{klass}[#{item.uuid}] json at #{Time.now}"

        # 不处理已经被删除的
        (DeleteCallback.call(klass.name, _uuid, _distribute_url); return false) if is_deleted

        paperclip_items = [item]
        # 获取embeds_many里的含有paperclip对象，目前只支持一级
        klass.relations.each do |k, v|
          next if not v.macro == :embeds_many
          paperclip_items += item.send(k).to_a
        end
        # 在paperclip文件对象选择上使用方法反射
        paperclip_regexp = /_([a-z_]+)_post_process_callbacks/
        paperclip_items.each do |paperclip_item|
          next if not paperclip_item.methods.include?(:upload_path)
          paperclip_method = paperclip_item.methods.detect {|m| m.match(paperclip_regexp) }.to_s.match(paperclip_regexp)[1]
          file_path = paperclip_item.send(paperclip_method).path
          next if not File.exists? file_path
          Rails.logger.info "[DistributeTree] begin sync #{klass}[#{item.uuid}] file at #{Time.now}"
          RestClient.put "#{_distribute_url}#{paperclip_item.upload_path}", :file => File.new(file_path, 'rb')
          Rails.logger.info "[DistributeTree] end   sync #{klass}[#{item.uuid}] file at #{Time.now}"
        end

        # distribute children
        item.distribute_children.each do |relation|
          item.send(relation).to_a.each do |item2|
            Resque.enqueue item2.class, item2.uuid, _distribute_url, is_with_children
          end
        end if is_with_children.to_s == 'true' # 兼容resque可能不能反序列化True/False

        DeleteCallback.call(klass.name, _uuid, _distribute_url)
      end

    end

  end
end
