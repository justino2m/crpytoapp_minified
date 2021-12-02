# needed to detect serialized xlsx file (otherwise detected as application/zip)
[
 ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', [[0, "PK\003\004",[[0..5000, 'xl/']]]]],
].each do |magic|
  MimeMagic.add(magic[0], magic: magic[1])
end

DEFAULT_PAPERCLIP_PATH = "/images/:class/:attachment/:id_partition/:style.:extension".freeze
if Rails.env.production?
  Paperclip::Attachment.default_options[:storage] = :s3
  Paperclip::Attachment.default_options[:s3_protocol] = :https
  Paperclip::Attachment.default_options[:s3_credentials] = {
    bucket: ENV['S3_BUCKET_NAME'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    s3_region: ENV['AWS_REGION'],
  }
  Paperclip::Attachment.default_options[:url] = ":s3_domain_url"
  Paperclip::Attachment.default_options[:path] = DEFAULT_PAPERCLIP_PATH
  Paperclip::Attachment.default_options[:default_url] = "/missing/:class.png"
else
  Paperclip::Attachment.default_options[:url] = "http://localhost:3000/assets#{DEFAULT_PAPERCLIP_PATH}"
  Paperclip::Attachment.default_options[:path] = "#{Rails.root}/public/assets#{DEFAULT_PAPERCLIP_PATH}"
  Paperclip::Attachment.default_options[:default_url] = "http://localhost:3000/missing/:class.png"
end

# this patch is needed to support text/csv which are always identified as text/plain
# by the content type detector. There are also 2 mime types for csv, we want to ignore
# the long one (comma-sep...)
Paperclip::ContentTypeDetector.class_eval do
  def calculated_type_matches
    possible_types.select do |content_type|
      type = type_from_file_contents
      content_type == type ||
        (%w[text/plain].include?(type) && content_type.start_with?('text/') && content_type != 'text/comma-separated-values')
    end
  end
end