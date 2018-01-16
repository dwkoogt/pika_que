module Fluffy
  class Rails < ::Rails::Engine

    config.before_configuration do
      if ::Rails::VERSION::MAJOR < 5 && defined?(::ActiveRecord)
        Fluffy.middleware do |chain|
          require 'fluffy/middleware/active_record'
          chain.add Fluffy::Middleware::ActiveRecord
        end
      end
    end

  end
end
