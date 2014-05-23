links=stories

stories: wordpress.xml
	node stories.js | jq -I -c -r '.objectId, .' > stories

redis:
	for links in $(links); do \
		cat $$links | while read id; read json; redis-cli sadd object:$id:links $json; end; \
	done;
