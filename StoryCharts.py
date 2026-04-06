
import os
import json
import copy
import webapp2
import logging
from google.appengine.ext import ndb
from google.appengine.api import mail
from google.appengine.api import users
from google.appengine.api import memcache
from google.appengine.ext.webapp import template

class StoryNDB(ndb.Model):
    title = ndb.StringProperty(indexed=False)
    private = ndb.BooleanProperty()
    userid = ndb.StringProperty()
    summary = ndb.TextProperty(indexed=False)
    date = ndb.DateTimeProperty(auto_now=True)
    
    @ndb.tasklet
    def to_dict_async(self):
        storyDict = ndb.Model.to_dict(self)
        storyDict['id'] = str(self.key.id())
        storyDict['date'] = str(self.date.strftime("%B %d %Y"))
        raise ndb.Return(storyDict)

class PlotNDB(ndb.Model):
    title = ndb.StringProperty(indexed=False)
    description = ndb.TextProperty(indexed=False)
    storyid = ndb.StringProperty()
    order = ndb.IntegerProperty()

    @ndb.tasklet
    def to_dict_async(self):
        plotDict = ndb.Model.to_dict(self)
        plotDict['id'] = str(self.key.id())
        raise ndb.Return(plotDict)

class SceneNDB(ndb.Model):
    title = ndb.StringProperty(indexed=False)
    description = ndb.TextProperty(indexed=False)
    storyid = ndb.StringProperty()
    order = ndb.IntegerProperty()

    @ndb.tasklet
    def to_dict_async(self):
        sceneDict = ndb.Model.to_dict(self)
        sceneDict['id'] = str(self.key.id())
        raise ndb.Return(sceneDict)

class TurningPointNDB(ndb.Model):
    title = ndb.StringProperty(indexed=False)
    storyid = ndb.StringProperty()
    plotid = ndb.StringProperty()
    sceneid = ndb.StringProperty()

    @ndb.tasklet
    def to_dict_async(self):
        tpDict = ndb.Model.to_dict(self)
        tpDict['id'] = str(self.key.id())
        raise ndb.Return(tpDict)

class IndexHandler(webapp2.RequestHandler):
  def get(self):
    if os.environ['PATH_INFO'] is not '/': return self.redirect('/')
    templateValues = dict()
    templateValues['HOST'] = "https://" + os.environ['HTTP_HOST']
    templateValues['USER'] = users.get_current_user()
    templateValues['STORIES'] = IndexHandler.getStories_async().get_result()
    templateValues['LOGINURL'] = users.create_login_url(os.environ['PATH_INFO'])
    templateValues['LOGOUTURL'] = users.create_logout_url(os.environ['PATH_INFO'])
    templatePath = os.path.join(os.path.dirname(__file__), 'templates' + os.sep + 'Index.html')
    self.response.out.write(template.render(templatePath, templateValues))

  @classmethod
  @ndb.tasklet
  def getStories_async(cls):
    storiesStr = memcache.get('stories')
    if storiesStr is not None: storiesDict = json.loads(storiesStr)
    else:
        stories = yield StoryNDB.query(ancestor=ndb.Key(StoryNDB, "Stories")).filter(StoryNDB.private == False).order(-StoryNDB.date).fetch_async()
        storiesDict = yield [story.to_dict_async() for story in stories]
        memcache.set('stories', json.dumps(storiesDict))
    if users.get_current_user() is None: raise ndb.Return( storiesDict )
    userStoriesStr = memcache.get('stories ' + users.get_current_user().user_id())
    if userStoriesStr is not None: userStoriesDict = json.loads(userStoriesStr)
    else:
        userStories = yield StoryNDB.query(ancestor=ndb.Key(StoryNDB, "Stories")).filter(StoryNDB.userid == users.get_current_user().user_id()).order(-StoryNDB.date).fetch_async()
        userStoriesDict = yield [story.to_dict_async() for story in userStories]
        memcache.set('stories ' + users.get_current_user().user_id(), json.dumps(userStoriesDict))
    raise ndb.Return( userStoriesDict )

class StoryHandler(webapp2.RequestHandler):
  def get(self):
    templateValues = dict()
    templateValues['HOST'] = "https://" + os.environ['HTTP_HOST']
    templateValues['USER'] = users.get_current_user()
    try:
        storyPackageDict = StoryHandler.getStory_async(str(os.environ['PATH_INFO'].split("/")[2])).get_result()
        storyDict = storyPackageDict['story']
        templateValues['STORY'] = storyDict
        templateValues['PLOTS'] = storyPackageDict['plots']
        templateValues['SCENES'] = storyPackageDict['scenes']
        templateValues['CHART'] = storyPackageDict['chart']
        if users.get_current_user():
            if users.get_current_user().user_id() != storyDict['userid']:
                templateValues['ADMIN'] = users.is_current_user_admin()
    except: return self.redirect('/')
    if storyDict['private']:
        if not users.get_current_user(): return self.redirect('/')
        elif users.get_current_user().user_id() != storyDict['userid']: return self.redirect('/')
    templatePath = os.path.join(os.path.dirname(__file__), 'templates' + os.sep + 'Story.html')
    self.response.out.write(template.render(templatePath, templateValues))

  def post(self):
    storyPackageDict = StoryHandler.getStory_async(str(os.environ['PATH_INFO'].split("/")[2])).get_result()
    self.response.headers['Content-Type'] = 'application/json'
    self.response.out.write(json.dumps(storyPackageDict))

  @classmethod
  @ndb.tasklet
  def getStory_async(cls, storyID):
    storyStr = memcache.get('story ' + storyID)
    if storyStr is not None: storyPackageDict = json.loads(storyStr)
    else:
        story = yield ndb.Key(StoryNDB, "Stories", StoryNDB, int(storyID)).get_async()
        storyDict = yield story.to_dict_async()
        plots = yield PlotNDB.query(ancestor=ndb.Key(PlotNDB, "Plots")).filter(PlotNDB.storyid == storyID).order(PlotNDB.order).fetch_async()
        plotsDict = yield [plot.to_dict_async() for plot in plots]
        scenes = yield SceneNDB.query(ancestor=ndb.Key(SceneNDB, "Scenes")).filter(SceneNDB.storyid == storyID).order(SceneNDB.order).fetch_async()
        scenesDict = yield [scene.to_dict_async() for scene in scenes]
        tps = yield TurningPointNDB.query(ancestor=ndb.Key(TurningPointNDB, "TurningPoints")).filter(TurningPointNDB.storyid == storyID).fetch_async()
        chart = True if len (tps) > 0 else False
        tpsDict = []
        for sceneDict in scenesDict:
            for plotDict in plotsDict:
                tp = TurningPointNDB.query(ancestor=ndb.Key(TurningPointNDB, "TurningPoints")).filter(TurningPointNDB.sceneid == sceneDict['id']).filter(TurningPointNDB.plotid == plotDict['id']).fetch()
                if len(tp) > 0:
                    tpsDict.append(tp[0].title)
                else:
                    tpsDict.append("None")
        storyPackageDict = { 'story': storyDict, 'plots': plotsDict, 'scenes': scenesDict, 'chart': chart, 'tps': tpsDict }
        memcache.set('story ' + storyID, json.dumps(storyPackageDict))
    raise ndb.Return( storyPackageDict )

  @classmethod
  @ndb.tasklet
  def emailStory_async(cls, storyID):
    if not users.get_current_user(): raise ndb.Return()
    storyPackageDict = yield StoryHandler.getStory_async(storyID)
    storyDict = storyPackageDict['story']
    scenesDict = storyPackageDict['scenes']
    plotsDict = storyPackageDict['plots']
    if users.get_current_user().user_id() != storyDict['userid']: raise ndb.Return()
    emailtext = "\n"
    if (storyDict['summary'] != ""):
        emailtext = "Summary\n\n" + storyDict['summary'] + "\n\n";
    for plotDict in plotsDict:
        emailtext = emailtext + plotDict['title'] + "\n\n" + plotDict['description'] + "\n\n"
    for sceneDict in scenesDict:
        emailtext = emailtext + sceneDict['title'] + "\n\n" + sceneDict['description'] + "\n\n"
    emailtext = emailtext + "\n"
    try:
        mail.send_mail(sender="StoryCharts@storycharts.appspotmail.com", to=users.get_current_user().email(), subject=storyDict['title'], body=emailtext)
    except: pass
    raise ndb.Return()

class CreateHandler(webapp2.RequestHandler):
  def get(self):
    if not users.get_current_user(): return self.redirect(users.create_login_url(os.environ['PATH_INFO']))
    templateValues = dict()
    templateValues['HOST'] = "https://" + os.environ['HTTP_HOST']
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(os.environ['PATH_INFO'].split("/")[2])).get()
        if story.userid != users.get_current_user().user_id(): return self.redirect('/')
        templateValues['STORY'] = story.to_dict_async().get_result()
    except: templateValues['STORY'] = None
    templatePath = os.path.join(os.path.dirname(__file__), 'templates' + os.sep + 'Create.html')
    self.response.out.write(template.render(templatePath, templateValues))

  def post(self):
    if not users.get_current_user(): return self.redirect('/')
    if not self.request.get('storyID'): story = StoryNDB(parent=ndb.Key(StoryNDB, "Stories"))
    else:
        try:
            story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(self.request.get('storyID'))).get()
            if users.is_current_user_admin():
                if self.request.get('makeprivate') != "":
                    story.private = True
                    story.put()
                    memcache.delete('stories')
                    memcache.delete('stories ' + story.userid)
                    memcache.delete('story ' + self.request.get('storyID'))
                    return self.redirect('/')
            if story.userid != users.get_current_user().user_id(): return self.redirect('/')
            if self.request.get('delete') != "":
                story.key.delete()
                plots = PlotNDB.query(ancestor=ndb.Key(PlotNDB, "Plots")).filter(PlotNDB.storyid == self.request.get('storyID')).order(PlotNDB.order).fetch()
                for plot in plots: plot.key.delete()
                scenes = SceneNDB.query(ancestor=ndb.Key(SceneNDB, "Scenes")).filter(SceneNDB.storyid == self.request.get('storyID')).order(SceneNDB.order).fetch()
                for scene in scenes: scene.key.delete()
                memcache.delete('stories')
                memcache.delete('stories ' + users.get_current_user().user_id())
                memcache.delete('story ' + self.request.get('storyID'))
                return self.redirect('/')
        except: return self.redirect('/')
    story.userid = users.get_current_user().user_id()
    story.private = True if self.request.get('private') == 'Private' else False
    story.title = self.request.get('title')
    story.summary = self.request.get('summary')
    story.put()
    memcache.delete('stories')
    memcache.delete('stories ' + users.get_current_user().user_id())
    memcache.delete('story ' + str(story.key.id()))
    StoryHandler.emailStory_async(str(story.key.id())).get_result()
    self.redirect('/story/' + str(story.key.id()) + '/')

class PlotHandler(webapp2.RequestHandler):
  def get(self):
    if not users.get_current_user(): return self.redirect('/')
    templateValues = dict()
    templateValues['HOST'] = "https://" + os.environ['HTTP_HOST']
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(os.environ['PATH_INFO'].split("/")[2])).get()
        templateValues['STORY'] = story.to_dict_async().get_result()
    except: return self.redirect('/')
    try:
        plot = ndb.Key(PlotNDB, "Plots", PlotNDB, int(os.environ['PATH_INFO'].split("/")[3])).get()
        templateValues['PLOT'] = plot.to_dict_async().get_result()
    except: templateValues['PLOT'] = None
    templatePath = os.path.join(os.path.dirname(__file__), 'templates' + os.sep + 'Plot.html')
    self.response.out.write(template.render(templatePath, templateValues))

  def post(self):
    if not users.get_current_user(): return self.redirect('/')
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(self.request.get('storyID'))).get()
        if story.userid != users.get_current_user().user_id(): return self.redirect('/')
    except: return self.redirect('/')
    if not self.request.get('plotID'):
        plot = PlotNDB(parent=ndb.Key(PlotNDB, "Plots"))
        plot.order = 100
    else:
        try:
            plot = ndb.Key(PlotNDB, "Plots", PlotNDB, int(self.request.get('plotID'))).get()
            if self.request.get('delete') != "":
                plot.key.delete()
                memcache.delete('story ' + self.request.get('storyID'))
                return self.redirect('/story/' + str(story.key.id()) + '/')
        except: return self.redirect('/')
    plot.storyid = self.request.get('storyID')
    plot.title = self.request.get('title')
    plot.description = self.request.get('description')
    plot.put()
    memcache.delete('story ' + self.request.get('storyID'))
    StoryHandler.emailStory_async(self.request.get('storyID')).get_result()
    self.redirect('/story/' + str(plot.storyid) + '/')

class SceneHandler(webapp2.RequestHandler):
  def get(self):
    if not users.get_current_user(): return self.redirect('/')
    templateValues = dict()
    templateValues['HOST'] = "https://" + os.environ['HTTP_HOST']
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(os.environ['PATH_INFO'].split("/")[2])).get()
        templateValues['STORY'] = story.to_dict_async().get_result()
    except: return self.redirect('/')
    try:
        scene = ndb.Key(SceneNDB, "Scenes", SceneNDB, int(os.environ['PATH_INFO'].split("/")[3])).get()
        templateValues['SCENE'] = scene.to_dict_async().get_result()
    except: templateValues['SCENE'] = None
    templatePath = os.path.join(os.path.dirname(__file__), 'templates' + os.sep + 'Scene.html')
    self.response.out.write(template.render(templatePath, templateValues))

  def post(self):
    if not users.get_current_user(): return self.redirect('/')
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(self.request.get('storyID'))).get()
        if story.userid != users.get_current_user().user_id(): return self.redirect('/')
    except: return self.redirect('/')
    if not self.request.get('sceneID'):
        scene = SceneNDB(parent=ndb.Key(SceneNDB, "Scenes"))
        scene.order = 100
    else:
        try:
            scene = ndb.Key(SceneNDB, "Scenes", SceneNDB, int(self.request.get('sceneID'))).get()
            if self.request.get('delete') != "":
                scene.key.delete()
                memcache.delete('story ' + self.request.get('storyID'))
                return self.redirect('/story/' + str(story.key.id()) + '/')
        except: return self.redirect('/')
    scene.storyid = self.request.get('storyID')
    scene.title = self.request.get('title')
    scene.description = self.request.get('description')
    scene.put()
    memcache.delete('story ' + self.request.get('storyID'))
    StoryHandler.emailStory_async(self.request.get('storyID')).get_result()
    self.redirect('/story/' + str(scene.storyid) + '/')

class OrderHandler(webapp2.RequestHandler):
  def get(self):
    templateValues = dict()
    templateValues['HOST'] = "https://" + os.environ['HTTP_HOST']
    try:
        storyPackageDict = StoryHandler.getStory_async(str(os.environ['PATH_INFO'].split("/")[2])).get_result()
        storyDict = storyPackageDict['story']
        templateValues['STORY'] = storyDict
        templateValues['PLOTS'] = storyPackageDict['plots']
        templateValues['SCENES'] = storyPackageDict['scenes']
    except: return self.redirect('/')
    if not users.get_current_user(): return self.redirect('/')
    if users.get_current_user().user_id() != storyDict['userid']: return self.redirect('/')
    templatePath = os.path.join(os.path.dirname(__file__), 'templates' + os.sep + 'Order.html')
    self.response.out.write(template.render(templatePath, templateValues))

  def post(self):
    plotids = self.request.get('plotsorder').strip().split(" ")
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(self.request.get('storyID'))).get()
        if not users.get_current_user(): return self.redirect('/')
        if users.get_current_user().user_id() != story.userid: return self.redirect('/')
        order = 1
        for plotid in plotids:
            plot = ndb.Key(PlotNDB, "Plots", PlotNDB, int(plotid)).get()
            plot.order = order
            order = order + 1
            plot.put()
        memcache.delete('story ' + self.request.get('storyID'))
    except: pass
    sceneids = self.request.get('scenesorder').strip().split(" ")
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(self.request.get('storyID'))).get()
        if not users.get_current_user(): return self.redirect('/')
        if users.get_current_user().user_id() != story.userid: return self.redirect('/')
        order = 1
        for sceneid in sceneids:
            scene = ndb.Key(SceneNDB, "Scenes", SceneNDB, int(sceneid)).get()
            scene.order = order
            order = order + 1
            scene.put()
        memcache.delete('story ' + self.request.get('storyID'))
    except: pass
    StoryHandler.emailStory_async(self.request.get('storyID')).get_result()
    return self.redirect('/story/' + self.request.get('storyID') + '/')

class ChartHandler(webapp2.RequestHandler):
  def get(self):
    templateValues = dict()
    templateValues['HOST'] = "https://" + os.environ['HTTP_HOST']
    try:
        storyPackageDict = StoryHandler.getStory_async(str(os.environ['PATH_INFO'].split("/")[2])).get_result()
        storyDict = storyPackageDict['story']
        scenesDict = storyPackageDict['scenes']
        plotsDict = storyPackageDict['plots']
        for sceneDict in scenesDict:
            sceneDict['PLOTS'] = copy.deepcopy(plotsDict)
            for plotDict in sceneDict['PLOTS']:
                tps = TurningPointNDB.query(ancestor=ndb.Key(TurningPointNDB, "TurningPoints")).filter(TurningPointNDB.sceneid == sceneDict['id']).filter(TurningPointNDB.plotid == plotDict['id']).fetch()
                if len(tps) > 0:
                    plotDict['tp'] = tps[0].title
                else:
                    plotDict['tp'] = "None"
        templateValues['STORY'] = storyDict
        templateValues['SCENES'] = scenesDict
        templateValues['CHART'] = storyPackageDict['chart']
    except: return self.redirect('/')
    if not users.get_current_user(): return self.redirect('/')
    if users.get_current_user().user_id() != storyDict['userid']: return self.redirect('/')
    templatePath = os.path.join(os.path.dirname(__file__), 'templates' + os.sep + 'Chart.html')
    self.response.out.write(template.render(templatePath, templateValues))

  def post(self):
    try:
        story = ndb.Key(StoryNDB, "Stories", StoryNDB, int(self.request.get('storyID'))).get()
        if not users.get_current_user(): return self.redirect('/')
        if users.get_current_user().user_id() != story.userid: return self.redirect('/')
        storyPackageDict = StoryHandler.getStory_async(self.request.get('storyID')).get_result()
        storyDict = storyPackageDict['story']
        plotsDict = storyPackageDict['plots']
        scenesDict = storyPackageDict['scenes']
        tps = TurningPointNDB.query(ancestor=ndb.Key(TurningPointNDB, "TurningPoints")).filter(TurningPointNDB.storyid == self.request.get('storyID')).fetch()
        for tp in tps: tp.key.delete()
        if self.request.get('delete') != "":
            memcache.delete('story ' + self.request.get('storyID'))
            return self.redirect('/story/' + self.request.get('storyID') + '/')
        tpchoices = self.request.get('tps').strip().split(" ")
        i = 0
        for sceneDict in scenesDict:
            for plotDict in plotsDict:
                tp = TurningPointNDB(parent=ndb.Key(TurningPointNDB, "TurningPoints"))
                tp.storyid = self.request.get('storyID')
                tp.sceneid = sceneDict['id']
                tp.plotid = plotDict['id']
                tp.title = tpchoices[i]
                i = i + 1
                tp.put()
    except: return self.redirect('/')
    memcache.delete('story ' + self.request.get('storyID'))
    return self.redirect('/story/' + self.request.get('storyID') + '/')


routes = [
    (r'/story/.*', 'StoryCharts.StoryHandler'),
    (r'/create/.*', 'StoryCharts.CreateHandler'),
    (r'/plot/.*', 'StoryCharts.PlotHandler'),
    (r'/scene/.*', 'StoryCharts.SceneHandler'),
    (r'/order/.*', 'StoryCharts.OrderHandler'),
    (r'/chart/.*', 'StoryCharts.ChartHandler'),
    (r'.*', 'StoryCharts.IndexHandler')]

config = {}
config['webapp2_extras.sessions'] = {
    'secret_key': "\xb7\xe2\xc7\xe3w\xe2\xf68\xaep\x02\xcf\x80\x8e\xdc1\xba\x0b\xc5V\xb8\x86'|\\\x1e\xb4d\xb1>Du@\x9d\xfa\x96@\x85Zs\xad\x02{\xb8r\xc2.\x8bV\xe0\xafs\xfb\xf4Z\xf9\x02\xbb\xc9a\xe8Rx\x0e"
}
app = webapp2.WSGIApplication(routes=routes, debug=True, config=config)
