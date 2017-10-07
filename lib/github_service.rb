class GithubService

  def getIssues(type='issues')

    url = CONFIG.github.api << "/#{type}?state=closed"
    url = url << '&labels=new feature' if type == 'issues'
    url = url << '&sort=updated' if type == 'issues'

    url_escape = URI.escape(url)
    uri = URI.parse(url_escape)
    req = Net::HTTP::Get.new(uri.to_s)
    req['Accept'] = 'application/vnd.github.v3+json'
    jres = []

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      res = http.request(req)

      jres = JSON.parse(res.body)
    rescue => e
      jres = [{"title" => "No hay nuevas noticias", "body" => "Servicio de noticias abajo"}]
    end
    jres[0..4]
  end

end