class Utils
  def self.state_from_html(html)
    doc = Nokogiri::HTML(html)
    scripts = doc.css("body script").map(&:content)
    state_script = scripts.select{|script| script =~ /initialState/}.first
    state = JSON.parse(state_script.match(/.*?({.*})\;/m)[1])
  end
end