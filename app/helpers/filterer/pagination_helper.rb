module Filterer
  module PaginationHelper

    def render_filterer_pagination(searcher)
      content_tag(:div, class: 'pagination-wrapper') do
        content_tag(:ul, class: 'unstyled') do
          content_tag(:li, class: searcher.meta[:page] == 1 ? "disabled" : '') do
            if searcher.meta[:page] == 1
              content_tag(:span) { '‹' }
            else
              content_tag(:a, class: 'pagination-previous',
                          href: calculate_filterer_pagination_url(searcher.meta[:page] - 1)) { '‹' }
            end
          end +

          searcher.paginator.pages.map do |p|
            if p == 'break'
              "<li><span>...</span></li>"
            else
              content_tag(:li, class: p == searcher.meta[:page] ? 'active' : '') do
                content_tag(:a, href: calculate_filterer_pagination_url(p)) { p.to_s }
              end
            end
          end.join('').html_safe +

          content_tag(:li, class: searcher.meta[:page] == searcher.meta[:last_page] ? "disabled" : '') do
            if searcher.meta[:page] == searcher.meta[:last_page]
              content_tag(:span) { '›' }
            else
              content_tag(:a, class: 'pagination-next', href: calculate_filterer_pagination_url(searcher.meta[:page] + 1)) { '›' }
            end
          end
        end
      end
    end

    def calculate_filterer_pagination_url(page)
      url_for(params.merge(page: page))
    end

  end
end
