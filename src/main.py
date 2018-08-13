from jnius import autoclass
import os, sys

Environment = autoclass('android.os.Environment')
File = autoclass('java.io.File')
Timezone = autoclass('java.util.TimeZone')

# TODO check for storage availibility
def get_home_folder():
    kolibri_home_file = File(Environment.getExternalStorageDirectory(), ".kolibri")
    # prevents content from showing up in things like "gallery"
    kolibri_home_file.createNewFile(".nomedia")
    return kolibri_home_file.toString()


sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), "kolibri", "dist"))

os.environ["DJANGO_SETTINGS_MODULE"] = "kolibri.deployment.default.settings.base"
os.environ["KOLIBRI_HOME"] = get_home_folder()
os.environ["TZ"] = Timezone.getDefault().toZoneId()

import django
django.setup()

from django.conf import settings
settings.DEBUG = False

from django.core.management import call_command
call_command("migrate", interactive=False, database="default")

call_command("collectstatic", interactive=False)

# remove this after Kolibri no longer needs it
if sys.version[0] == '2':
    reload(sys)
    sys.setdefaultencoding('utf8')

from kolibri.utils.server import run_server
run_server(5000)
