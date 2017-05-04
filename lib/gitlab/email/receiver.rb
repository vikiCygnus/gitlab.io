
require_dependency 'gitlab/email/handler'

# Inspired in great part by Discourse's Email::Receiver
module Gitlab
  module Email
    ProcessingError = Class.new(StandardError)
    EmailUnparsableError = Class.new(ProcessingError)
    SentNotificationNotFoundError = Class.new(ProcessingError)
    ProjectNotFound = Class.new(ProcessingError)
    EmptyEmailError = Class.new(ProcessingError)
    AutoGeneratedEmailError = Class.new(ProcessingError)
    UserNotFoundError = Class.new(ProcessingError)
    UserBlockedError = Class.new(ProcessingError)
    UserNotAuthorizedError = Class.new(ProcessingError)
    NoteableNotFoundError = Class.new(ProcessingError)
    InvalidNoteError = Class.new(ProcessingError)
    InvalidIssueError = Class.new(ProcessingError)
    UnknownIncomingEmail = Class.new(ProcessingError)

    class Receiver
      def initialize(raw)
        @raw = raw
      end

      def execute
        raise EmptyEmailError if @raw.blank?

        mail = build_mail
        mail_key = extract_mail_key(mail)
        handler = Handler.for(mail, mail_key)

        raise UnknownIncomingEmail unless handler

        Gitlab::Metrics.add_event(:receive_email,
                                  project: handler.try(:project),
                                  handler: handler.class.name)

        handler.execute
      end

      private

      def build_mail
        Mail::Message.new(@raw)
      rescue Encoding::UndefinedConversionError,
             Encoding::InvalidByteSequenceError => e
        raise EmailUnparsableError, e
      end

      def extract_mail_key(mail)
        key_from_to_header(mail) || key_from_additional_headers(mail)
      end

      def key_from_to_header(mail)
        mail.to.find do |address|
          key = Gitlab::IncomingEmail.key_from_address(address)
          break key if key
        end
      end

      def key_from_additional_headers(mail)
        find_key_from_references(mail) ||
          find_key_from_delivered_to_header(mail)
      end

      def ensure_references_array(references)
        case references
        when Array
          references
        when String
          # Handle emails from clients which append with commas,
          # example clients are Microsoft exchange and iOS app
          Gitlab::IncomingEmail.scan_fallback_references(references)
        end
      end

      def find_key_from_references(mail)
        ensure_references_array(mail.references).find do |mail_id|
          key = Gitlab::IncomingEmail.key_from_fallback_message_id(mail_id)
          break key if key
        end
      end

      def find_key_from_delivered_to_header(mail)
        Array(mail[:delivered_to]).find do |header|
          key = Gitlab::IncomingEmail.key_from_address(header.value)
          break key if key
        end
      end
    end
  end
end
