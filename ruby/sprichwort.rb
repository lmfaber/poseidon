#!/usr/bin/env ruby

require 'open-uri'

class Sprichwort

  attr_reader :sprichwort

  def initialize
    begin
      remote = open('http://proverb.gener.at/or/')
      @sprichwort = "#{remote.read.scan(/spwort\">.*</)[0].sub('spwort">','').sub('<','')}"
    rescue
      @sprichwort = 'A straw attracts the woodmans axe.'
    end
  end
end






