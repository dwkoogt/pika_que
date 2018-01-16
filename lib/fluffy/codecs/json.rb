require 'json'

module Fluffy
  module Codecs
    module JSON
      extend self

      def encode(payload)
        ::JSON.generate(payload)
      end

      def decode(payload)
        ::JSON.parse(payload, quirks_mode: true)
      end

      def content_type
        'application/json'
      end

    end
  end
end
