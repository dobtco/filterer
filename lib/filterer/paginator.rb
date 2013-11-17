module Filterer
  class Paginator

    attr_reader :pages

    def initialize(searcher)
      @searcher = searcher

      if @searcher.meta[:last_page] == 1
        @pages = [1]
        return
      end

      @pages = [1, 2]

      push_page(@searcher.meta[:last_page])
      push_page(@searcher.meta[:last_page] - 1)

      offset = 0
      current_page = @searcher.meta[:page]

      while @pages.length < 11 && ( (current_page - offset >= 1) || (current_page + offset <= @searcher.meta[:last_page]) ) do
        push_page(current_page - offset)
        push_page(current_page + offset)
        offset += 1
      end

      add_breaks
    end

    def add_breaks
      pages_without_breaks = @pages.sort
      pages_with_breaks = []

      pages_without_breaks.each_with_index do |p, i|
        if pages_without_breaks[i - 1] && (p - pages_without_breaks[i - 1] > 1)
          pages_with_breaks.push 'break'
        end

        pages_with_breaks.push p
      end

      @pages = pages_with_breaks
    end

    def push_page(page)
      @pages.push(page) unless @pages.include?(page) || (page > @searcher.meta[:last_page]) || (page < 1)
    end

  end
end
