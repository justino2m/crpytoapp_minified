module CsvProcessor
  extend ActiveSupport::Concern

  CSV_MIME_TYPES = %w[text/csv text/comma-separated-values text/plain]
  EXCEL_MIME_TYPES = %w[application/vnd.ms-excel application/vnd.openxml application/xls application/octet-stream]

  def prepare_and_set_file
    decoded_file = Paperclip.io_adapters.for(file).read.force_encoding("utf-8")
    file_name = file.original_filename
    first_line = decoded_file.first(50)

    if first_line.start_with?("PK\003\004") # serialized xlsx file
      doc_options = { extension: 'xlsx' }
    elsif first_line.start_with?("\xD0\xCF\x11\xE0".force_encoding("utf-8")) # microsoft xls file (97-2003)
      doc_options = { extension: 'xls' }
    elsif first_line.start_with?("bplist") # icloud bplist file
      return fail! "file type is not supported"
    elsif first_line.length > 2
      doc_options = { extension: 'csv' }

      # handle encoding
      if decoded_file.first(50).bytes[3..15].count(0) >= 5 && decoded_file.last(100).bytes.last(20).count(0) >= 5 # okex, huobi, tidex, gate.io
        decoded_file.force_encoding "utf-16le"
        decoded_file.encode! Encoding::UTF_8, invalid: :replace, undef: :replace, replace: ''
      end
      decoded_file.slice!("\xEF\xBB\xBF".force_encoding("utf-8")) # bom

      begin
        # some files contain the quote escape char itself so we have to remove it
        # ex "This is \"My Wallet\" okay"
        # here the My Wallet string is not actually escaped and will result in a "Missing or stray quote in line x" error
        decoded_file.gsub!(/\\"|"(?:\\"|[^"])*"/) { |x| "\"#{x[1..-2].gsub('\"', '')}\"" } if decoded_file.include?('\"')

        # replace commas, semicolons and newlines inside quotes so we can detect the correct column separator
        cleaned_data = decoded_file.first(2000).gsub(/("([^"]|"")*")/) { |x| x.gsub(/[,\;\n]/, ' ') }
      rescue ArgumentError => e
        if e.message.start_with?('invalid byte sequence')
          decoded_file = decoded_file.force_encoding('ISO-8859-1').encode("utf-8", replace: '')
          should_retry = @retried_invalid_seq.nil?
          @retried_invalid_seq = true
          retry if should_retry
        end
        raise
      end

      back_r = cleaned_data.split(/\r(?!\n)/).count # \r not followed by \n
      back_n = cleaned_data.split(/(?<!\r)\n/).count # \n not preceded by \r
      back_rn = cleaned_data.split("\r\n").count

      # pick the separator with highest occurances
      row_sep = "\r\n" if back_rn > back_n && back_rn > back_r
      row_sep ||= back_r > back_n ? "\r" : "\n"

      # some files can contain the wrong line break on the first/last line which messes up the csv detection
      decoded_file = decoded_file.gsub("\r", "") if row_sep == "\n" && back_r > 0
      decoded_file = decoded_file.gsub("\r\n", "\r") if row_sep == "\r" && back_rn > 0

      # for the new-line separator we have to first replace all new lines inside quotes then replace the incorrect line returns
      # ex: "Date,Time,\"Humanize\nDescription\",Id\n1,2,3,4\r\n1,2,3,4"
      if back_n > 0 && row_sep != "\n"
        # replace new line chars within quotes with space
        decoded_file = decoded_file.gsub(/\\"|"(?:\\"|[^"])*"/) { |x| x.gsub("\n", ' ') }
        # replace new line chars thats are not preceded by \r\n with \r\n
        decoded_file = decoded_file.gsub(/\r?\n/) { |x| x.include?("\r\n") ? x : x.sub("\n", "\r\n") } if row_sep == "\r\n"
        # replace new line chars with \r
        decoded_file = decoded_file.gsub(/\n/, "\r") if row_sep == "\r"
      end

      # reinit the cleaned_data
      cleaned_data = decoded_file.first(2000).gsub(/("([^"]|"")*")/) { |x| x.gsub(/[,\;\n]/, ' ') }
      lines = cleaned_data.split(row_sep)

      # count the number of occurances of each separator for every row
      stats = lines.take(20).map { |line| [line.count(','), line.count(';'), line.count("\t")] }.transpose

      # find the separator with highest number of same occurances
      seps = [{ sep: "," }, { sep: ";" }, { sep: "\t" }]
      seps[0][:count], seps[1][:count], seps[2][:count] = stats.map { |arr| arr.tally.delete_if { |k, _| k.zero? }.values.sort.last || 0 }
      seps[0][:row], seps[1][:row], seps[2][:row] = stats.map.with_index { |arr, idx| arr.index(arr.tally.invert[seps[idx][:count]]) }

      # small files might not have enough similar occurances, in such cases select the separator with
      # highest number of occurances on same row
      if seps.all? { |sep| sep[:count] == seps[0][:count] }
        seps[0][:count], seps[1][:count], seps[2][:count] = stats.map { |arr| arr.sort.last }
        seps[0][:row], seps[1][:row], seps[2][:row] = stats.map.with_index { |arr, idx| arr.index(seps[idx][:count]) }
      end

      sep = seps.sort_by { |sep| sep[:count] }.last
      col_sep = sep[:sep]
      data_row = sep[:row]

      # detect header row, it sometimes doesnt have the last comma, also skip any initial rows
      # that have too many blank columns (more than half the total columns) as thats usually just text
      minimum_header_cols = lines[data_row].count(col_sep) - 1
      header_row = lines.index do |line|
        split = line.split(col_sep)
        [line.count(col_sep), split.count].max >= minimum_header_cols && split.count(&:present?) > minimum_header_cols / 2
      end

      if header_row && header_row > 0
        # get rid of the bogus lines before the header
        # note that because we are replacing certain chars in the cleaned_data we may not find a
        # match to this header row if it contained these characters
        starting_data_idx = decoded_file.index(lines[header_row].first(30))
        decoded_file = decoded_file[starting_data_idx..-1] if starting_data_idx.present?
      end

      doc_options.merge!(csv_options: {
                           col_sep: col_sep,
                           row_sep: row_sep,
                           quote_char: "\"",
                         })
    else
      return fail! "file is empty"
    end

    processed_file = Tempfile.new(file_name, encoding: 'ascii-8bit')
    processed_file.write(decoded_file)
    processed_file.close # must close or spreadsheet will be empty for certain csv files

    begin
      spreadsheet = Roo::Spreadsheet.open(processed_file, doc_options.dup)
      return fail! 'Spreadsheet is empty' if spreadsheet.last_row.blank? || spreadsheet.last_row <= 1
    rescue Zip::Error, ArgumentError, CSV::MalformedCSVError => e
      return fail! "Invalid file: #{e.message}"
    end

    # fail if csv only has one column, thos can happen if the user puts quotes around the rows ex:
    #   "\"ID,Type,Txhash\""
    first_row = spreadsheet.each.take(1).first
    return fail! "Not enough columns in csv file" if doc_options[:extension] == 'csv' && first_row.count <= 1

    # sometimes users copy/paste a csv into an excel file so all columns end up on the same row
    # we can detect this by checking if all but the first column contain blank values
    if doc_options[:extension] != 'csv' && spreadsheet.sheets.count == 1 && spreadsheet.each.take(20).all? { |row| row[1..-1].all?(&:blank?) }
      return fail! "Not enough columns in excel file"
    end

    decoded_file = StringIO.new(decoded_file)
    decoded_file.original_filename = file_name
    decoded_file.original_filename += ".#{doc_options[:extension]}" unless file_name.end_with?(".#{doc_options[:extension]}")

    self.initial_rows = spreadsheet.each.take(20)
    self.file_col_sep =  doc_options.dig(:csv_options, :col_sep)
    self.file_row_sep =  doc_options.dig(:csv_options, :row_sep)
    if potential_mappers.present?
      self.file = decoded_file # only override original file if we have mappers for it otherwise we want to see the untouched one
      self.mapping_id = auto_detect_mapping_id
      warn_if_wrong_mapper if mapping_id
    end
    # user.fraud_detector.check_csv_import(file_name, initial_rows) if initial_rows.present?
    save!
  end

  def auto_detect_mapping_id
    return if potential_mappers.empty?

    # dont auto set if there are multiple matches for the highest score
    best_id, best_score = potential_mappers.first
    return if potential_mappers.count { |_, v| v == best_score } > 1
    best_id
  end

  def warn_if_wrong_mapper
    # this is useful as it shows us mappers that might be matching to files that are generated by some other exchange
    mapper_tag = mapper.mapping[:importer_tag] || mapper.class.tag
    wallet_tag = wallet.wallet_service&.tag
    if mapper_tag.present? && wallet_tag.present? && mapper_tag != wallet_tag
      Rollbar.debug(
        "Matched #{mapping_id} to wallet #{wallet.name} (#{wallet_tag})",
        wallet_id: wallet.id,
        file_url: file.url,
        file_name: file_file_name
      )
    end
  end
end
