var fs = require('fs')
var parseString = require('xml2js').parseString
var uniq = require("uniq")
var out = []

parseString(fs.readFileSync('./import/wordpress.xml', 'utf8'), {trim: true, explicitArray: false}, function(err, result) {
  var items = result.rss.channel.item
  items.forEach(function(item) {
    if(item['content:encoded'].match(/artsmia.org\/search/)) console.error('fix search URL', item['link'])

    var objectUrlPattern = /collections\.artsmia\.org\/(.*detail&amp;id=)?(art\/)?\d+/g
    var objectMatch = item['content:encoded'].match(objectUrlPattern)
    if(objectMatch != undefined && item['wp:status'] == 'publish') {
      var ids = objectMatch.map(function(url) {
        var match = url.match(/(?:art\/|id=)(\d+)/)
        return match && match[1]  // || url.match(/collections.artsmia.org\/)[1]
      })
      out.push({
        title: item.title,
        link: "http://new.artsmia.org/stories/"+item['wp:post_name']+"/",
        objectIds: uniq(ids).join(' ')
      })
    }
  })
})

console.log(JSON.stringify(out))
