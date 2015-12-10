$(document).ready(function(){
  $('.right.menu.open').on("click",function(e){
    e.preventDefault();
    $('.ui.vertical.menu').toggle();
  });

  $('#upload-btn').on("click", function(e){
    e.preventDefault();
    $('.ui.modal').modal('show');
  });

  $("#demo-upload").dropzone(
    { 
      url: "/upload",
      clickable: true,
      init: function() {
        this.on("complete", function(data, response) { 
          var uid = JSON.parse(data.xhr.response);
          window.location = window.location.href + "file/" + uid["uid"];
      });
      }
      // init: function() {
      // this.on("complete", function(file, responseText) {
      //     console.log(responseText);
      //   });
      // }
  });
});
