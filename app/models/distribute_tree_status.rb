# encoding: UTF-8

class DistributeTreeStatus
  include Mongoid::Document; self.store_in database: self.name.underscore
  include Mongoid::Timestamps

  field :item_class, type: String
  field :item_uuid,  type: String
  field :server_url, type: String

  index({item_class: 1, item_uuid: 1, server_url: 1}, {background: true})

  def self.insert item_class, item_uuid, server_url; DistributeTreeStatus.find_or_create_by(item_class: item_class, item_uuid: item_uuid, server_url: server_url) end
  def self.delete item_class, item_uuid, server_url; DistributeTreeStatus.where(item_class: item_class, item_uuid: item_uuid, server_url: server_url).delete_all  end

end
