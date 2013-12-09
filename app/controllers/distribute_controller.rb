# encoding: UTF-8
class DistributeController < ApplicationController

  #######################
  #####  A. creator  ####
  #######################

  def create
    error_messages = []
    error_messages << "Missing model name" if params[:model_name].blank?
    error_messages << "Missing uuid" if params[:uuids].blank?
    error_messages << "Please select an school" if params[:school_uuids].blank?

    if not error_messages.blank?
      render json: {status: "error", messages: error_messages}, status: :bad_request; return false
    end

    server_urls = School.where(uuid: {"$in" => params[:school_uuids]}).map(&:server_url)

    params[:uuids].to_a.each do |uuid|
      item = params[:model_name].classify.safe_constantize.uuid(uuid)
      item.distribute_with_children(server_urls)
    end

    render json: {status: "success", messages: ["已加入到发送队列"]}
  end

  def servers
    @schools = School.asc(:_id).where(is_enable_sync: true)
    render layout: false
  end

  def index
    data = DistributeTreeStatus.where(
      item_class: params[:model_name],
      item_uuid:  {"$in" => params[:uuids]},
    ).to_a.inject({}) do |h, status|
      h[status.item_uuid] ||= []
      h[status.item_uuid] << status.server_url
      h
    end

    render json: {status: 'success', data: data }
  end

  # TODO
  def paperclip_file
    params[:model_name].constantize
  end

  #######################
  #####  B. receiver ####
  #######################

  def receive
    payload = params[:payload]

    unless payload and payload[:model_name]
      render json: {status: 'error', message: "payload and model_name required"}
      return
    end

    model = payload[:model_name].classify().constantize

    uuid = nil
    if payload[:model] and payload[:model].is_a?(Hash)
      uuid = payload[:model][:uuid]
    end

    unless model and uuid
      render json: {status: 'error', message: "model and uuid not identified"}
      return
    end

    model = model.unscoped # 兼容被删除资源

    if payload[:model][:delete]
      model.where(uuid: uuid).destroy_all
      render json: {status: 'success', message: "model deleted"}
      return
    end

    if model.where(uuid: uuid).exists?
      # update, skip validation
      item = model.uuid(uuid)
    elsif [Piece, Image].include? model
      # Local不自动创建Piece和Image, 只更新老师添加的
      render json: {status: 'success'}
      return
    else
      item = model.new
    end

    payload[:model].delete '_id'

    item.assign_attributes payload[:model], without_protection: true
    item.deleted_at = nil if payload[:model][:deleted_at].blank? # 恢复删除。也许assign_attributes payload[:model]这里面已经包含了。
    if item.save validate: false
      render json: {status: 'success'}
    else
      render json: {status: 'error', message: "fail to create or update model"}
    end
  end

end
