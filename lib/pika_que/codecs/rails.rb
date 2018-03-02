require 'active_support/json'

module PikaQue
  module Codecs
    module RAILS
      extend self

      def encode(payload)
        ::ActiveSupport::JSON.encode(payload)
      end

      def decode(payload)
        ::ActiveSupport::JSON.decode(payload)
      end

      def content_type
        'application/json'
      end

    end
  end
end
