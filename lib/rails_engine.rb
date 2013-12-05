# encoding: UTF-8

module DistributeTree

  class Engine < Rails::Engine
    initializer "distribute_tree.load_app_instance_data" do |app|
      app.class.configure do
        ['app/assets', 'app/controllers', 'app/views'].each do |path|
          config.paths[path] ||= []
          config.paths[path] += DistributeTree::Engine.paths[path].existent
        end
      end
    end
  end

end
