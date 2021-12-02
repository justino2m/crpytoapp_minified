# this is so we can set file names for data blobs that are passed to paperclip
StringIO.class_eval do
  attr_accessor :original_filename
end
