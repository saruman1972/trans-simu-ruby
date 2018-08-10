require 'sequel'

DB = Sequel.connect("sqlite://orgsim.db")

class Card < Sequel::Model
end

Card.all.each do |card|
  p card
end

card = Card.filter(:SEQ_NO => 2).first
p card.CARD_NO
