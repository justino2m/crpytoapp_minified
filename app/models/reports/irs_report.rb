class IrsReport < Report
  TEMPLATE_PATH = Rails.root.join('lib', 'assets', 'f8949_2018.pdf').freeze
  SUMMARY_TEMPLATE_PATH = Rails.root.join('lib', 'assets', 'f1040sd_2018.pdf')

  def supported_formats
    [:pdf]
  end

  def generate
    shorts = []
    longs = []
    analytics.capital_gains_disposals.each do |disposal|
      row_array = row(disposal)
      if disposal[:long_term]
        longs << row_array
      else
        shorts << row_array
      end
    end

    {
      short_term: shorts,
      long_term: longs
    }
  end

  def to_pdf(rows)
    setup_report
    process_totals(rows)
    process_gains(rows, :short_term)
    process_gains(rows, :long_term)
    combine_pages
  end

  protected

  def row(disposal)
    [
      [disposal[:amount].to_s, disposal[:symbol]].join(' '),
      display_date(disposal[:acquired_on], "%m.%d.%Y"),
      display_date(disposal[:sold_on], "%m.%d.%Y"),
      disposal[:selling_price],
      disposal[:buying_price],
      nil,
      nil,
      (disposal[:gain] < 0 ? "(#{disposal[:gain].abs.to_s})" : disposal[:gain]),
    ]
  end

  def process_totals(rows)
    proceeds_short = sum_row(rows[:short_term], 3)
    cost_short = sum_row(rows[:short_term], 4)
    result_short = proceeds_short - cost_short
    result_short = "(#{result_short.abs})" if result_short < 0

    proceeds_long = sum_row(rows[:long_term], 3)
    cost_long = sum_row(rows[:long_term], 4)
    result_long = proceeds_long - cost_long
    result_long = "(#{result_long.abs})" if result_long < 0

    summary_path = File.join(@report_temp_dir, "#{@current_page.to_s.rjust(3, '0')}.pdf")
    Prawn::Document.generate(summary_path, right_margin: 0) do |pdf|
      pdf.fill_color Report::FONT_COLOR
      pdf.move_down(267)
      pdf.font_size = 9
      pdf.indent(250) do
        pdf.table(
          [[proceeds_short.to_s, cost_short.to_s, '', result_short.to_s]],
          column_widths: [71, 71, 74, 70],
          cell_style: {borders: [], height: 24}
        )
      end

      pdf.move_down(276)
      pdf.indent(250) do
        pdf.table(
          [[proceeds_long.to_s, cost_long.to_s, '', result_long.to_s]],
          column_widths: [71, 71, 74, 70],
          cell_style: {borders: [], height: 24}
        )
      end

      # top right in bold
      pdf.fill_color('ffffff')
      pdf.rectangle([498, 705], 25, 25)
      pdf.fill
      pdf.fill_color('000000')
      pdf.draw_text("#{year.to_s.last(2)}", at: [497, 685.5], size: 20, style: :bold)

      # bottom right small bold on page 1
      pdf.fill_color('ffffff')
      pdf.rectangle([522.5, 9], 20, 10)
      pdf.fill
      pdf.fill_color('000000')
      pdf.draw_text("#{year.to_s}", at: [523, 2], size: 7, style: :bold)

      # bottom right small bold on page 2
      pdf.start_new_page
      pdf.fill_color('ffffff')
      pdf.rectangle([522.5, 153], 20, 10)
      pdf.fill
      pdf.fill_color('000000')
      pdf.draw_text("#{year.to_s}", at: [525, 146], size: 7, style: :bold)

      # top left small bold on page 2
      pdf.fill_color('ffffff')
      pdf.rectangle([76, 720], 20, 10)
      pdf.fill
      pdf.fill_color('000000')
      pdf.draw_text("#{year.to_s}", at: [78, 713], size: 7)
    end
    summary_template = CombinePDF.load(SUMMARY_TEMPLATE_PATH)
    summary_file = CombinePDF.load(summary_path)
    summary_template.pages.first << summary_file.pages.first
    summary_template.pages.second << summary_file.pages.second
    summary_template.save(summary_path)
    @current_page = @current_page.next
    nil
  end

  def process_gains(rows, gains_type)
    rows[gains_type].each_slice(14) do |group|
      report_path = File.join(@report_temp_dir, "#{@current_page.to_s.rjust(3, '0')}.pdf")
      irs_gains_to_pdf(group, report_path, gains_type)

      template = CombinePDF.load(self.class::TEMPLATE_PATH)
      report_page = CombinePDF.new

      # this is used to fill in the template
      report = CombinePDF.load(report_path)
      if gains_type == :short_term
        report_page << template.pages.first
        report_page.pages.first << report.pages.first
      else
        report_page << template.pages.second
        report_page.pages.first << report.pages.first
      end
      report_page.save(report_path)
      # make sure we increment the page number
      @current_page = @current_page.next
    end
  end

  def irs_gains_to_pdf(group, report_path, gains_type)
    group_totals = [[
      sum_row(group, 3).to_s,
      sum_row(group, 4).to_s,
      '',
      '',
      sum_row(group, 7).to_s,
    ]]
    group_totals[0][-1] = "(#{group_totals[0][-1].to_d.abs.to_s})" if group_totals[0][-1].to_d < 0

    Prawn::Document.generate(report_path, right_margin: 0) do |pdf|
      pdf.fill_color Report::FONT_COLOR
      pdf.font_size 9
      pdf.move_down(gains_type == :short_term ? 314 : 277)
      pdf.table(group, column_widths: [138, 52, 52, 64, 64, 50, 60, 80], cell_style: { borders: [], height: 24, padding: [5, 0, 5, 0] })
      pdf.font_size 11
      pdf.move_cursor_to(gains_type == :short_term ? 490.5 : 526.5)
      pdf.indent 15 do
        pdf.text "X"
      end
      pdf.move_cursor_to(gains_type == :short_term ? 60 : 95)
      pdf.font_size 9
      pdf.indent(242) do
        pdf.table(group_totals, column_widths: [64, 64, 50, 60, 80], cell_style: { borders: [], height: 24, padding: [5, 0, 5, 0] })
      end

      if gains_type == :short_term
        # top right in bold
        pdf.fill_color('ffffff')
        pdf.rectangle([497, 707], 26, 20)
        pdf.fill
        pdf.fill_color('000000')
        pdf.draw_text("#{year.to_s.last(2)}", at: [497, 690], size: 20, style: :bold)

        # bottom right small on page 1
        pdf.fill_color('ffffff')
        pdf.rectangle([520.5, -2], 20, 10)
        pdf.fill
        pdf.fill_color('000000')
        pdf.draw_text("(#{year.to_s})", at: [521, -9], size: 7)
      else
        # bottom right small on page 2
        pdf.fill_color('ffffff')
        pdf.rectangle([520.5, 35], 20, 10)
        pdf.fill
        pdf.fill_color('000000')
        pdf.draw_text("(#{year.to_s})", at: [521, 27], size: 7)

        # top left small bold on page 2
        pdf.fill_color('ffffff')
        pdf.rectangle([36, 720], 20, 10)
        pdf.fill
        pdf.fill_color('000000')
        pdf.draw_text("(#{year.to_s})", at: [36, 712.5], size: 7)
      end
    end
  end
end