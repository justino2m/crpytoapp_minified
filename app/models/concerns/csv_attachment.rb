module CsvAttachment
  extend ActiveSupport::Concern

  module ClassMethods
    def has_csv_attachment(attr, options={})
      url = Paperclip::Attachment.default_options[:url]
      path = Paperclip::Attachment.default_options[:path]
      new_path = "/#{options[:base] || ':class'}/:id_partition/:filename"

      params = {
        url: url.start_with?(':s3_') ? url : url.gsub(::DEFAULT_PAPERCLIP_PATH, new_path),
        path: path.gsub(::DEFAULT_PAPERCLIP_PATH, new_path)
      }

      params.merge!(validate_media_type: false) if options[:validate_media_type] == false

      has_attached_file(attr, params)

      allowed_types = %w[
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        application/vnd.ms-excel
        text/csv
        text/comma-separated-values
        text/plain
      ]
      validates_attachment(attr, { content_type: { content_type: allowed_types + (options[:additional_types] || []) } }.merge(options))
    end
  end
end
