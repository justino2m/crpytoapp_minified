class SkatteverketK4Report < Report
  TEMPLATE_PATH = Rails.root.join('lib', 'assets', 'k4_2019.pdf').freeze

  def supported_formats
    [:pdf]
  end

  def generate
    profits = analytics.asset_profit_summary.map{ |x| row(x, true) }
    losses = analytics.asset_loss_summary.map{ |x| row(x, false) }
    (profits + losses).sort_by{ |h| h[1] }
  end

  def to_pdf(rows)
    setup_report
    process_gains(rows)
    combine_pages
  end

  protected

  def row(asset, is_profit)
    [
      asset[:amount].ceil.to_i,
      asset[:symbol],
      asset[:proceeds].round.to_i,
      asset[:costs].round.to_i,
      (is_profit ? asset[:net].round.to_i : nil),
      (is_profit ? nil : asset[:net].round.abs.to_i)
    ]
  end

  def process_gains(rows)
    rows.each_slice(7) do |group|
      group = group.compact
      report_path = File.join(@report_temp_dir, "#{@current_page.to_s.rjust(3, '0')}.pdf")
      gains_to_pdf(group, report_path)

      # this is used to fill in the template
      template = CombinePDF.load(TEMPLATE_PATH)
      report = CombinePDF.load(report_path)
      template.pages.first << report.pages.first
      template.pages.second << report.pages.second

      template.save(report_path)
      # make sure we increment the page number
      @current_page = @current_page.next
    end
  end

  def gains_to_pdf(group, report_path)
    group_totals = [[
      sum_row(group, 2).round.to_i.to_s,
      sum_row(group, 3).round.to_i.to_s,
      sum_row(group, 4).round.to_i.to_s,
      sum_row(group, 5).round.to_i.to_s,
    ]]

    Prawn::Document.generate(report_path, right_margin: 0, left_margin: 52) do |pdf|
      # top right in bold
      pdf.fill_color('ffffff')
      pdf.rectangle([298, 726], 35, 20)
      pdf.fill
      pdf.fill_color('000000')
      pdf.draw_text("#{year.to_s}", at: [299, 712], size: 13)

      pdf.fill_color Report::FONT_COLOR
      pdf.font_size(9)
      pdf.move_down(37)
      pdf.indent(435) do
        pdf.text(@current_page.to_s)
      end
      pdf.start_new_page
      pdf.move_down(378)
      pdf.table(group, column_widths: [65, 95, 87, 87, 87, 87], cell_style: { borders: [], height: 24 })
      pdf.move_cursor_to(168)
      pdf.indent(160) do
        pdf.table(group_totals, cell_style: { borders: [], height: 24 }, column_widths: [87, 87, 87, 87])
      end
    end
  end
end
