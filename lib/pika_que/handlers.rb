module PikaQue
  module Handlers

    autoload :DefaultHandler, 'pika_que/handlers/default_handler'
    autoload :ErrorHandler, 'pika_que/handlers/error_handler'
    autoload :RetryHandler, 'pika_que/handlers/retry_handler'
    autoload :DLXRetryHandler, 'pika_que/handlers/dlx_retry_handler'

  end
end
