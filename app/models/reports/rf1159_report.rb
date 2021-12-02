class Rf1159Report < Report
  TEMPLATE_PATH = Rails.root.join('lib', 'assets', 'rf1159b_2018.pdf').freeze

  def supported_formats
    [:pdf]
  end

  def generate
    analytics.asset_summary.map(&method(:row))
  end

  def to_pdf(rows)
    setup_report
    process_gains(rows)
    combine_pages
  end

  protected

  def headers
    [
      "Navn på selskap",
      "Type verdipapir",
      "Antal aksjerr", # how many coins you still own -> round up to whole numbers (this is optional)
      "Formue", # value of the coins at end of calendar year
      "Gevinst", # profits this year on disposals
      "Tap", # loss on disposals
    ]
  end

  def row(disposal)
    [
      disposal[:symbol],
      "VV",
      "", # todo: how many coins you still own -> round up to whole numbers (this is optional)
      0, # todo: enter value of owned coins at end of calendar year in NOK
      disposal[:profit],
      disposal[:loss],
    ]
  end

  def process_gains(rows)
    rows.each_slice(17) do |group|
      report_path = File.join(@report_temp_dir, "#{@current_page.to_s.rjust(3, '0')}.pdf")
      gains_to_pdf(group, report_path)
      # due to the white overlay on this template we have to reverse how we combine
      # the template and pdf and we have to load the pdf for each page
      # and then add the page to the template, rather than the other way round

      @template = CombinePDF.load(TEMPLATE_PATH)
      # this is used to fill in the template
      report = CombinePDF.load(report_path)
      @template.pages.first << report.pages.first

      @template.save(report_path)
      # make sure we increment the page number
      @current_page = @current_page.next
    end
  end

  def gains_to_pdf(group, report_path)
    Prawn::Document.generate(report_path, page_layout: :landscape) do |pdf|
      pdf.fill_color Report::FONT_COLOR
      pdf.font_size(9)
      pdf.move_down(178)
      pdf.table(group, column_widths: [203, 215, 40, 67, 62, 40], cell_style: {borders: [], height: 20.3})

      # add year
      pdf.fill_color('eaffea')
      pdf.rectangle([755, 508], 40, 20)
      pdf.fill
      pdf.fill_color('000000')
      pdf.draw_text(year.to_s, at: [758, 493.5], size: 13, style: :bold)
    end
  end
end