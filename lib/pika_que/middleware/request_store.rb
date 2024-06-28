# Add manually if you need it
module PikaQue
  module Middleware
    class RequestStore

      def call(*args)
        yield
      ensure
        ::RequestStore.clear!
      end

    end
  end
end
