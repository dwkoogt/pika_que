module Fluffy
  module Codecs
    module NOOP
      extend self

      def encode(payload)
        payload
      end

      def decode(payload)
        payload
      end

      def content_type
        nil
      end

    end
  end
end
