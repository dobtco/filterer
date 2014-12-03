require 'spec_helper'

module PaginatorSpecHelper
  def assert_paginator_calculate_pages(last_page, current_page, expected_result)
    f = Filterer::Paginator.new(OpenStruct.new(meta: { last_page: last_page, page: current_page }))
    expect(f.pages).to eq(expected_result)
  end
end

include PaginatorSpecHelper

describe Filterer::Paginator do

  it 'calculates pages correctly' do
    assert_paginator_calculate_pages 1, 1, [1]
    assert_paginator_calculate_pages 2, 1, [1, 2]
    assert_paginator_calculate_pages 5, 1, [1, 2, 3, 4, 5]
    assert_paginator_calculate_pages 15, 1, [1, 2, 3, 4, 5, 6, 7, 8, 9, 'break', 14, 15]
    assert_paginator_calculate_pages 15, 5, [1, 2, 3, 4, 5, 6, 7, 8, 9, 'break', 14, 15]
    assert_paginator_calculate_pages 15, 10, [1, 2, 'break', 7, 8, 9, 10, 11, 12, 13, 14, 15]
    assert_paginator_calculate_pages 100, 40, [1, 2, "break", 37, 38, 39, 40, 41, 42, 43, "break", 99, 100]
    assert_paginator_calculate_pages 100, 100, [1, 2, "break", 92, 93, 94, 95, 96, 97, 98, 99, 100]
  end

end
