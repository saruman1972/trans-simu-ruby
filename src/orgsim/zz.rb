require 'csv'

rows = CSV.read('institution/bos2.1/card.csv')
#print rows
rows.each do |row|
    print row, "\n"
end

