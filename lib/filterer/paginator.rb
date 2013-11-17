module Filterer
  class Paginator

    attr_reader :pages

    def initialize(searcher)
      @searcher = searcher
      return @pages = [1] if @searcher.meta[:last_page] == 1
      push_default_pages
      calculate_additional_pages
      add_breaks
    end

    def push_default_pages
      @pages = [1, 2]
      push_page(@searcher.meta[:last_page], @searcher.meta[:last_page] - 1)
    end

    def calculate_additional_pages
      offset = 0
      current_page = @searcher.meta[:page]

      while @pages.length < 11 && ( (current_page - offset >= 1) || (current_page + offset <= @searcher.meta[:last_page]) ) do
        push_page(current_page - offset, current_page + offset)
        offset += 1
      end
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

    def push_page(*args)
      args.each do |page|
        @pages.push(page) unless @pages.include?(page) || (page > @searcher.meta[:last_page]) || (page < 1)
      end
    end

  end
end
