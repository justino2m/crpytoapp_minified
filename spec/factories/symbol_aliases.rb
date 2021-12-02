FactoryBot.define do
  factory :symbol_alias do
    currency nil
    symbol "MyString"
    tag SymbolAlias::COMMON_TAG
  end
end
