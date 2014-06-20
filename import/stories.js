var fs = require('fs')
var parseString = require('xml2js').parseString
var uniq = require("uniq")
var out = []

parseString(fs.readFileSync('./import/wordpress.xml', 'utf8'), {trim: true, explicitArray: false}, function(err, result) {
  var items = result.rss.channel.item
  items.forEach(function(item) {
    var objectMatch = item['content:encoded'].match(/collections\.artsmia\.org.*detail&amp;id=\d+/g)
    if(objectMatch != undefined && item['wp:status'] == 'publish') {
      var ids = objectMatch.map(function(url) { return url.match(/id=(\d+)/)[1] })
      out.push({
        title: item.title,
        link: "http://new.artsmia.org/stories/"+item['wp:post_name']+"/",
        objectIds: uniq(ids).join(' ')
      })
    }
  })
})

console.log(JSON.stringify(out))
