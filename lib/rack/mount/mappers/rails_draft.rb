require 'active_support/inflector'

module Rack
  module Mount
    module Mappers
      class RailsDraft
        def initialize(set)
          require 'action_controller'
          @set = set
          @scope_stack = []
        end

        def get(path, options = {})
          match(path, options.merge(:method => :get))
        end

        def post(path, options = {})
          match(path, options.merge(:method => :post))
        end

        def put(path, options = {})
          match(path, options.merge(:method => :put))
        end

        def delete(path, options = {})
          match(path, options.merge(:method => :delete))
        end

        def match(path, options = {})
          new_options = {}
          method = options.delete(:method)
          requirements = options.delete(:constraints) || {}
          defaults = {}

          if controller = scope_options[:controller]
            defaults[:controller] = controller.to_s
          end

          if to = options.delete(:to)
            controller, action = to.to_s.split("#")

            if defaults[:controller]
              defaults[:action] = controller if controller
            else
              defaults[:controller] = controller if controller
              defaults[:action] = action if action
            end
          end

          if defaults.has_key?(:controller)
            app = "#{defaults[:controller].camelize}Controller"
            app = ActiveSupport::Inflector.constantize(app)
          else
            app = lambda { |env|
              app = "#{env["rack.routing_args"][:controller].camelize}Controller"
              app = ActiveSupport::Inflector.constantize(app)
              app.call(env)
            }
          end

          @set.add_route({
            :app => app,
            :path => path,
            :method => method,
            :requirements => requirements,
            :defaults => defaults
          })
        end

        def controller(controller, &block)
          @scope_stack.push({:controller => controller})
          instance_eval(&block)
        ensure
          @scope_stack.pop
        end

        def resources(*entities, &block)
          options = entities.extract_options!
          entities.each { |entity| map_resource(entity, options.dup, &block) }
        end

        private
          def scope_options
            options = {}
            @scope_stack.each { |opts| options.merge!(opts) }
            options
          end

          def map_resource(entities, options = {}, &block)
            resource = ActionController::Resources::Resource.new(entities, options)

            get(resource.path, :to => "#{resource.controller}#index")
            post(resource.path, :to => "#{resource.controller}#create")
            get(resource.new_path, :to => "#{resource.controller}#new")
            get("#{resource.member_path}/edit", :to => "#{resource.controller}#edit")
            get(resource.member_path, :to => "#{resource.controller}#show")
            put(resource.member_path, :to => "#{resource.controller}#update")
            delete(resource.member_path, :to => "#{resource.controller}#destroy")
          end
      end
    end
  end
end
