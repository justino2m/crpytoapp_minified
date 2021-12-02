module Api
  class CsvImportsController < ResourceController
    before_action :set_user_id, only: [:create]
    before_action :ensure_wallet_supplied, only: [:create]
    before_action :prepare_and_set_file, only: [:create]

    private

    # file, file_name are set in the before_Action callbacks
    def allowed_create_attributes
      [
        :wallet_id,
        :mapping_id,
        :timezone
      ]
    end

    def allowed_update_attributes
      [
        :mapping_id
      ]
    end

    def set_user_id
      default_params[:user_id] = current_user.id
    end

    def ensure_wallet_supplied
      if resource_params[:wallet_id].present?
        bad_args 'wallet is invalid' unless current_user.wallets.where(id: resource_params[:wallet_id]).exists?
      elsif resource_params[:wallet_name].present?
        default_params[:wallet_id] = current_user.wallets.where(name: resource_params[:wallet_name]).first_or_create!.id
      else
        bad_args 'wallet is required'
      end
    end

    def prepare_and_set_file
      bad_args 'file is required' unless resource_params[:file].present?
      mime_type = resource_params[:file].content_type
      excel = %w[application/vnd.ms-excel application/vnd.openxml application/xls application/octet-stream].any? { |s| mime_type.start_with?(s) }
      csv = %w[text/csv text/comma-separated-values text/plain].any? { |s| mime_type.start_with?(s) }
      bad_args "unknown file type #{mime_type}" unless excel || csv

      extension = excel ? 'xlsx' : 'csv'
      file_name = resource_params[:file].original_filename
      decoded_file = resource_params[:file].read

      first_line = decoded_file.first(100)
      last_line = decoded_file.last(100)

      if last_line.end_with?("\r\x00\n\x00") || first_line.start_with?("I\x00d\x00,\x00T\x00i\x00m\x00e\x00") # bittrex/gate or tidex
        # bittrex, tidex, gate.io
        # decoded_file.chars.map.with_index { |x, idx| idx.odd? ? x : nil }.compact.all?("\x00") # tidex deposits/withdrawals
        decoded_file.force_encoding "utf-16le"
        decoded_file.encode! "utf-8"
      elsif first_line.start_with?("\xEF\xBB\xBF".force_encoding("ASCII-8BIT"))
        # huobi files: remove bom characters
        decoded_file.gsub!("\xEF\xBB\xBF".force_encoding("ASCII-8BIT"), '')
      elsif first_line.match(/txnotes\n/i)
        # localbitcoins have this issue
        decoded_file.gsub!(/\R/, "\n") # replace all line endings with \n
      elsif file_name.start_with?('Coinbase') && (file_name.include?('Transfers') || file_name.include?('Transactions') || first_line.include?('likely tax obligations'))
        # coinbase files contain bad rows in the beginning
        decoded_file = decoded_file.partition(/Timestamp,/)[-2..-1].join
      elsif first_line.include?('Requester')
        # wirex
        decoded_file = decoded_file.partition(/#,Operation,Time/)[-2..-1].join
      elsif first_line.include?('Disclaimer: All data is without')
        # bitpanda contain some bad rows
        if decoded_file.first(500).match(/Transaction ID"?,"?External Transaction ID/) # bitpanda ge txns
          decoded_file = decoded_file.partition(/"?Transaction ID"?,"?External/)[-2..-1].join
        elsif decoded_file.first(500).include?('ID,Type,') # Bitpanda txns
          decoded_file = decoded_file.partition(/ID,Type/)[-2..-1].join
        end
      elsif file_name.include?('Universal') && file_name.end_with?('csv')
        # cointracker
        decoded_file.gsub!(/\R/, "\n") # replace all line endings with \n
      elsif file_name.match(/etoro/i)
        decoded_file.force_encoding "utf-8"
      elsif first_line.start_with?('DISCLAIMER: This report does not constitute')
        # abra
        decoded_file = decoded_file.partition(/Transaction date/)[-2..-1].join
      elsif first_line.start_with?("sep=,\r\n")
        # deribit files
        decoded_file.slice!(0, 7)
        decoded_file.gsub!(/\R/, "\n")
      end

      file = Tempfile.new(file_name, encoding: 'ascii-8bit')
      file.write(decoded_file)
      file.close # must close or spreadsheet will be empty for certain csv files

      # note: dont set any csv_options here as the file will be reopened later when importing,
      # instead format the file so it can be opened without any options!
      options = { extension: extension, csv_options: {} }
      begin
        begin
          spreadsheet = Roo::Spreadsheet.open(file, options.dup)
          spreadsheet.last_row
        rescue Zip::Error, ArgumentError => e
          # binance exports DepositHistory.csv file which is actually excel so it causes
          # exception when we try to parse it as csv. So, we parse csv files as excel
          # just in case...
          # note: sometimes csv files can come up as zip files which also causes this error
          # ArgumentError Exception: invalid byte sequence in UTF-8
          options.merge!(extension: excel ? 'csv' : 'xlsx')
          spreadsheet = Roo::Spreadsheet.open(file, options.dup)
          spreadsheet.last_row
        end
      rescue CSV::MalformedCSVError => e
        # this can happen when a csv contains quote chars, not sure why...
        # CSV::MalformedCSVError Exception: Illegal quoting in line 1
        options[:csv_options][:quote_char] = "\x00"
        begin
          spreadsheet = Roo::Spreadsheet.open(file, options.dup)
          spreadsheet.last_row
        rescue => e2
          Rollbar.error(e2)
          bad_args "Bad CSV file: " + e2.message
        end
      end

      bad_args 'spreadsheet is empty' if spreadsheet.last_row <= 1

      # semicolon delimited file
      if spreadsheet.take(1).first.count == 1 && spreadsheet.take(1).first[0].count(';') > 3
        default_params[:file_col_sep] = ';'
        options[:csv_options][:col_sep] = ';'
        spreadsheet = Roo::Spreadsheet.open(file, options.dup)
      end

      # tab delimited file
      if spreadsheet.take(1).first.count == 1 && spreadsheet.take(1).first[0].count("\t") > 3
        default_params[:file_col_sep] = "\t"
        options[:csv_options][:col_sep] = "\t"
        spreadsheet = Roo::Spreadsheet.open(file, options.dup)
      end

      decoded_file = StringIO.new(decoded_file)
      decoded_file.original_filename = file_name
      decoded_file.original_filename += ".#{options[:extension]}" unless file_name.end_with?(".#{options[:extension]}")
      default_params[:file] = decoded_file
      default_params[:initial_rows] = spreadsheet.each.take 20
    end
  end
end
