This tracks "links" between resources and objects in Mia's collection.

* [ArtStories](https://artstories.artsmia.org)
* [Mia Stories](https://new.artsmia.org/stories)
* Audio Tour "stops"
* [NewsFlashes](https://twitter.com/hcmaruyama/status/827950261293502467)
* Info on previous conservation projects
* Relevant artwork catalogs/publications

etc…

# How it works

`Makefile` has tasks that pull JSON from disparate sources and wrangle
it into cohesive line-delimited JSON files that look something like this:

```json
{"type":"3d","title":"Mia's Doryphoros","link":"https://sketchfab.com/models/8a54983061b74de4bf8b7ca2aca25990","thumb":"<image link>","objectId":"3520"}
{"type":"3d","title":"Lion Statuette, c. 1200","link":"https://sketchfab.com/models/96becab79a604f3a97cbb0a70e55f9b1","thumb":"<image link>","objectId":"19884"}
```

Each type can have different data, but needs one or more `objectId`s,
a title, and a link to the source of the related content.

This data is used by @artsmia/collection-elasticsearch to index
relations into our ElasticSearch powered search, so we can show [search results for objects with
related content](https://collections.artsmia.org/search/_exists_:%22related*%22)
and also [all content related to a given artwork](https://collections.artsmia.org/art/1226)
