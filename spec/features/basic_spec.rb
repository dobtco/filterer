require 'spec_helper'

module BasicSpecHelper
  def ensure_page_links(*args)
    expect(page).to have_selector('nav.pagination')

    args.each do |x|
      if x.is_a?(Integer)
        expect(page).to have_link(x)
      else
        expect(page).to have_selector('li', text: x)
      end
    end
  end
end

include BasicSpecHelper

describe 'Filterer', :type => :feature do

  subject { page }

  describe 'pagination' do
    before do
      300.times { Person.create(name: 'Foo bar', email: 'foo@bar.com') }
      visit people_path
    end

    it 'renders the pagination correctly' do
      ensure_page_links(2, 3, 4, 5)
      expect(page).to have_selector('span.current', text: '1')
    end

    it 'properly links between pages' do
      click_link '2'
      ensure_page_links(1, 3, 4, 5, 6)
      expect(page).to have_selector('span.current', text: '2')
    end
  end

  describe 'filtering' do
    before do
      5.times { Person.create(name: 'Foo bar', email: 'foo@bar.com') }
      Person.create(name: 'Adam')
    end

    it 'displays all people' do
      visit people_path
      expect(page).to have_selector('.person', count: 6)
    end

    it 'properly filters the results' do
      visit people_path(name: 'Adam')
      expect(page).to have_selector('.person', count: 1)
    end
  end

  describe 'sorting' do
    let!(:bill) { Person.create(name: 'Bill', email: 'foo@bar.com') }
    let!(:adam) { Person.create(name: 'Adam', email: 'foo@bar.com') }

    it 'sorts properly' do
      visit people_path
      expect(find('.person:eq(1)')).to have_text 'Adam'
      expect(find('.person:eq(2)')).to have_text 'Bill'
    end

    it 'reverses sort' do
      visit people_path(direction: 'desc')
      expect(find('.person:eq(1)')).to have_text 'Bill'
      expect(find('.person:eq(2)')).to have_text 'Adam'
    end

    it 'changes sort option' do
      visit people_path(sort: 'id')
      expect(find('.person:eq(1)')).to have_text 'Bill'
      expect(find('.person:eq(2)')).to have_text 'Adam'

      visit people_path(sort: 'id', direction: 'desc')
      expect(find('.person:eq(1)')).to have_text 'Adam'
      expect(find('.person:eq(2)')).to have_text 'Bill'
    end
  end

end
