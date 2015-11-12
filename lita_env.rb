module Lita
  def self.env
    ENV["LITA_ENV"] || :development
  end

  def self.env?(env=:development)
    self.env.to_s == env.to_s
  end
end
