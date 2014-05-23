var fs = require('fs')
var parseString = require('xml2js').parseString
var out = []

parseString(fs.readFileSync('./import/wordpress.xml', 'utf8'), {trim: true, explicitArray: false}, function(err, result) {
  var items = result.rss.channel.item
  items.forEach(function(item) {
    var objectMatch = item['content:encoded'].match(/collections\.artsmia\.org.*detail&amp;id=(\d+)/)
    if(objectMatch != undefined) out.push({title: item.title, link: item.link, objectId: objectMatch[1]})
  })
})

console.log(JSON.stringify(out))
