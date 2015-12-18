var express = require('express');
var router = express.Router();

/* GET home page. */
router.get('/', function(req, res, next) {
  res.render('index', { title: 'Express' });
});

router.get('/maintenance', function(req, res, next) {
  res.render('maintenance', {title: 'Maintenance' });
});

router.post('/login', function(req, res, next) {
  res.send("<h1>Logged in as " + req.body.username + "</h1>");
});

router.post('/task', function(req, res, next) {
  res.send("<h1>Created new task with title: " + req.body.title + "</h1>");
});

module.exports = router;
