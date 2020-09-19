var app = new Vue({
  el: '#app',
  data: {
    data: [],
    completed: 0,
    total: 0,
    name: ""
  },
  methods: {
    format_bytes: function(bytes) {
      return (bytes/1024).toFixed(0) + "KB";
    }
  }
})

Vue.component('peer-info', {
  props: ['ip', 'status', 'piece', 'downloaded'],
  template: '<tr><td>{{ ip }}</td> <td>{{ status }}</td> <td>{{ piece }}</td> <td>{{ downloaded }}</td></tr>'
})

const socket = new WebSocket('ws://localhost:3000/socket');

// Connection opened
socket.addEventListener('open', function (event) {
    console.log("opened web socket connection")
});

// Listen for messages
socket.addEventListener('message', function (event) {
  
  // console.log('Message from server ', event.data);
  torrent_status = JSON.parse(event.data)
  app.data = torrent_status.peers
  app.completed = torrent_status.completed
  app.total = torrent_status.total
  app.name = torrent_status.name
});
