require 'spec_helper'

describe 'ActiveRecord' do
  it 'finds for a model' do
    included = Person.create(name: 'b')
    excluded = Person.create(name: 'c')

    params = { name: 'b' }
    expect(PersonFilterer).to receive(:new).with(params, anything).and_call_original
    expect(Person.filter(params)).to eq [included]
  end

  it 'preserves an existing query' do
    person = Person.create(name: 'b')
    expect(Person.where(name: 'b').filter).to eq [person]
    expect(Person.where(name: 'asdf').filter).to eq []
  end

  it 'finds for a model' do
    expect(PersonFilterer).to receive(:new).with({}, anything).and_call_original
    Company.filter({}, filterer_class: 'PersonFilterer')
  end

  it 'finds for a relation' do
    company = Company.create(name: 'foo')
    included = Person.create(company: company)
    excluded = Person.create

    expect(Company.first.people.filter).to eq [included]
  end

  it 'throws the correct error when not found' do
    expect do
      Company.all.filter({})
    end.to raise_error(/CompanyFilterer/)
  end
end
