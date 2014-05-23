// Given an object id, return all links

var redis = require('redis')
  , client = redis.createClient()
  , express = require('express')
  , app = express()
  , cors = require('cors')

app.use(cors())

app.get('/work/:id', function(req, res) {
  var key = 'object:'+req.params.id+':links'
  client.smembers(key, function(err, reply) {
    res.render('object.jade', {id: req.params.id, links: reply.map(function(line) { return JSON.parse(line) })})
  })
})

app.get('/', function(req, res) {
  client.keys('*:links', function(err, objectLinks) {
    var m = client.multi()
    // Redis multi-query: batch all the queries up and
    objectLinks.forEach(function(link) { m.smembers(link) })
    // execute once
    m.exec(function(err, replies) {
      replies = replies.map(function(reply, index) {
        return {
          id: objectLinks[index].split(':')[1],
          links: reply.map(function(line) { return JSON.parse(line) })
        }
      })
      console.log(replies)
      res.render('index.jade', {linkedObjects: replies})
    })
  })
})

app.listen(44444)
