class Utils
  def self.state_from_html(html)
    doc = Nokogiri::HTML(html)
    scripts = doc.css("head script").map(&:content)
    state_script = scripts.select{|script| script =~ /__initialState/}.first
    state = JSON.parse(state_script.match(/.*?({.*})\;/m)[1])
  end
end