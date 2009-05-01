require 'strscan'

module Rack
  module Mount
    module Recognition
      module Route #:nodoc:
        def self.included(base)
          base.class_eval do
            alias_method :initialize_without_recognition, :initialize
            alias_method :initialize, :initialize_with_recognition
          end
        end

        attr_writer :throw

        def initialize_with_recognition(*args)
          initialize_without_recognition(*args)

          @throw          = Const::NOT_FOUND_RESPONSE
          @path_keys      = path_keys(@path, %w( / ))
          @keys           = generate_keys
          @named_captures = named_captures(@path)
        end

        def call(env)
          method = env[Const::REQUEST_METHOD]
          path = env[Const::PATH_INFO]

          if (@method.nil? || method == @method) && path =~ @path
            routing_args, param_matches = @defaults.dup, $~.captures
            @named_captures.each { |k, i|
              if v = param_matches[i]
                routing_args[k] = v
              end
            }
            env[Const::RACK_ROUTING_ARGS] = routing_args
            @app.call(env)
          else
            @throw
          end
        end

        def path_keys_at(index)
          @path_keys[index]
        end

        KEYS = [:method]

        attr_reader :keys

        10.times do |n|
          module_eval(<<-EOS, __FILE__, __LINE__)
            def path_keys_at_#{n}
              @path_keys[#{n}]
            end
            KEYS << :"path_keys_at_#{n}"
          EOS
        end

        KEYS.freeze

        private
          # Keys for inserting into NestedSet
          # #=> ['people', /[0-9]+/, 'edit']
          def path_keys(regexp, separators)
            escaped_separators = separators.map { |s| Regexp.escape(s) }
            separators_regexp = Regexp.compile(escaped_separators.join('|'))
            segments = []

            begin
              Utils.extract_regexp_parts(regexp).each do |part|
                raise ArgumentError if part.is_a?(Utils::Capture)

                part = part.dup
                part.gsub!(/\\\//, '/')
                part.gsub!(/^\//, '')

                scanner = StringScanner.new(part)

                until scanner.eos?
                  unless s = scanner.scan_until(separators_regexp)
                    s = scanner.rest
                    scanner.terminate
                  end

                  s.gsub!(/\/$/, '')
                  raise ArgumentError if matches_separator?(s, separators)
                  segments << (clean_regexp?(s) ? s : nil)
                end
              end

              segments << Const::EOS_KEY
            rescue ArgumentError
              # generation failed somewhere, but lets take what we can get
            end

            Utils.pop_trailing_nils!(segments)

            segments.freeze
          end

          def generate_keys
            KEYS.inject({}) { |keys, k|
              if v = send(k)
                keys[k] = v
              end
              keys
            }
          end

          # Maps named captures to their capture index
          # #=> { :controller => 0, :action => 1, :id => 2, :format => 4 }
          def named_captures(regexp)
            named_captures = {}
            regexp.named_captures.each { |k, v|
              named_captures[k.to_sym] = v.last - 1
            }
            named_captures.freeze
          end

          def clean_regexp?(source)
            source =~ /^\w+$/
          end

          def matches_separator?(source, separators)
            separators.each do |separator|
              if Regexp.compile("^#{source}$") =~ separator
                return true
              end
            end
            false
          end
      end
    end
  end
end
