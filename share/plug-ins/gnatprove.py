"""This file provides support for using the GNATprove tool.

   GNATprove is a tool to apply automatic program proof to Ada programs.
   This plugin allows the user to perform a proof run and integrate its output
   into GPS.
   See menu Prove.
"""

############################################################################
## No user customization below this line
############################################################################

import GPS, os_utils, os.path

xml_gnatprove = """<?xml version="1.0"?>
  <GNATPROVE>

    <tool name="GNATprove" package="Prove" attribute="switches" index="">
      <language>Ada</language>
      <switches columns="2" lines="3" switch_char="-">
        <title line="1">Proof</title>
        <combo line="1" label="Report mode" switch="--report" separator="="
               noswitch="fail" tip="Amount of information reported">
          <combo-entry label="fail" value="fail"
                       tip="Only failed proof attempts"/>
          <combo-entry label="all" value="all"
                       tip="All proof attempts"/>
          <combo-entry label="detailed" value="detailed"
                       tip="Detailed proof attempts"/>
        </combo>
        <spin label="Prover timeout" switch="--timeout="
              default="1" min="1" max="3600"
              tip="Set the prover timeout (in s) for individual VCs" />
        <spin label="Prover max steps" switch="--steps="
              default="0" min="0" max="1000000"
              tip="Set the prover maximum number of steps for individual VCs" />
        <title line="1" column="2">Process control</title>
        <spin label="Multiprocessing" column="2" switch="-j"
              default="1" min="1" max="100"
              tip="Use N processes to compile and prove. On a multiprocessor machine compilation and proof will occur in parallel" />
      </switches>
    </tool>

    <target-model name="gnatprove">
       <description>Target model for GNATprove</description>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
       </command-line>
       <icon>gps-build-all</icon>
       <switches command="%(tool_name)s" columns="2" lines="1">
         <title column="1" line="1" >Compilation</title>
         <check label="Force Recompilation" switch="-f" column="1"
                tip="All actions are redone entirely, including compilation and proof" />
         <title column="2" line="1" >Proof</title>
         <check label="Report Proved VCs" switch="--report=all" column="2"
                tip="Report the status of all VCs, including those proved" />
         <spin label="Prover Timeout" switch="--timeout=" column="2"
                default="1" min="1" max="3600"
                tip="Set the prover timeout (in s) for individual VCs" />
       </switches>
    </target-model>

    <target model="gnatprove" name="Prove All" category="GNATprove">
       <in-menu>FALSE</in-menu>
       <icon>gps-build-all</icon>
       <launch-mode>MANUALLY_WITH_DIALOG</launch-mode>
       <read-only>TRUE</read-only>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
          <arg>--mode=prove</arg>
          <arg>--ide-progress-bar</arg>
          <arg>-U</arg>
       </command-line>
    </target>

    <target model="gnatprove" name="Prove Root Project" category="GNATprove">
       <in-menu>FALSE</in-menu>
       <icon>gps-build-all</icon>
       <launch-mode>MANUALLY_WITH_DIALOG</launch-mode>
       <read-only>TRUE</read-only>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
          <arg>--mode=prove</arg>
          <arg>--ide-progress-bar</arg>
       </command-line>
    </target>

    <target model="gnatprove" name="Prove File" category="GNATprove">
       <in-menu>FALSE</in-menu>
       <icon>gps-build-all</icon>
       <launch-mode>MANUALLY_WITH_DIALOG</launch-mode>
       <read-only>TRUE</read-only>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
          <arg>--mode=prove</arg>
          <arg>--ide-progress-bar</arg>
          <arg>-u</arg>
          <arg>%fp</arg>
       </command-line>
    </target>

    <target model="gnatprove" name="Prove Subprogram" category="GNATprove">
       <in-menu>FALSE</in-menu>
       <icon>gps-build-all</icon>
       <launch-mode>MANUALLY_WITH_DIALOG</launch-mode>
       <read-only>TRUE</read-only>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
          <arg>--mode=prove</arg>
          <arg>--ide-progress-bar</arg>
       </command-line>
    </target>

    <target model="gnatprove" name="Prove Line" category="GNATprove">
       <in-menu>FALSE</in-menu>
       <icon>gps-build-all</icon>
       <launch-mode>MANUALLY_WITH_DIALOG</launch-mode>
       <read-only>TRUE</read-only>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
          <arg>--mode=prove</arg>
          <arg>--ide-progress-bar</arg>
          <arg>--limit-line=%f:%l</arg>
       </command-line>
    </target>

    <target-model name="gnatprovable">
       <description>Target model for GNATprove in detection mode</description>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
       </command-line>
       <icon>gps-build-all</icon>
       <switches command="%(tool_name)s" columns="1" lines="1">
         <title column="1" line="1" >Compilation</title>
         <check label="Force Recompilation" switch="-f" column="1"
                tip="All actions are redone entirely, including compilation and proof" />
       </switches>
    </target-model>

    <target model="gnatprovable" name="Show Unprovable Code" category="GNATprove">
       <in-menu>FALSE</in-menu>
       <icon>gps-build-all</icon>
       <launch-mode>MANUALLY_WITH_DIALOG</launch-mode>
       <read-only>TRUE</read-only>
       <command-line>
          <arg>gnatprove</arg>
          <arg>-P%PP</arg>
          <arg>--mode=detect</arg>
          <arg>-f</arg>
       </command-line>
    </target>

  </GNATPROVE>
"""

prefix               = "Prove"
menu_prefix          = "/" + prefix
prove_all            = "Prove All"
prove_root_project   = "Prove Root Project"
prove_file           = "Prove File"
prove_line           = "Prove Line"
prove_subp           = "Prove Subprogram"
show_unprovable_code = "Show Unprovable Code"

# Check for GNAT toolchain: gnatprove

gnatprove = os_utils.locate_exec_on_path("gnatprove")

# This is the context of a subprogram declaration if there is a subprogram,
# there is a corresponding declaration, and their file:line locations match.
def is_subp_decl_context(self):
    if isinstance (self, GPS.EntityContext) and \
       self.entity() and \
       self.entity().category() == "subprogram" and \
       self.entity().declaration() and \
       self.location().file() == self.entity().declaration().file() and \
       self.location().line() == self.entity().declaration().line():
        return True
    else:
        return False

# This is the context of a subprogram body if there is a subprogram, there is a
# corresponding body, and their file:line locations match.
def is_subp_body_context(self):
    if isinstance (self, GPS.EntityContext) and \
       self.entity() and \
       self.entity().category() == "subprogram" and \
       self.entity().body() and \
       self.location().file() == self.entity().body().file() and \
       self.location().line() == self.entity().body().line():
        return True
    else:
        return False

def is_subp_context(self):
    return is_subp_decl_context(self) or is_subp_body_context(self)

def mk_loc_string (sloc):
    locstring = os.path.basename(sloc.file().name()) + ":" + str(sloc.line())
    return locstring

def on_prove_all(self):
    GPS.BuildTarget(prove_all).execute(synchronous=False)

def on_prove_root_project(self):
    GPS.BuildTarget(prove_root_project).execute(synchronous=False)

def on_prove_file(self):
    GPS.BuildTarget(prove_file).execute(synchronous=False)

def on_prove_line(self):
    GPS.BuildTarget(prove_line).execute(synchronous=False)

# The argument --limit-subp is not defined in the prove_subp build target,
# because we have no means of designating the proper location at that point.
# A mild consequence is that --limit-subp does not appear in the editable
# box shown to the user, even if appears in the uneditable argument list
# displayed below it.
def on_prove_subp(self):
    loc = self.entity().declaration()
    target = GPS.BuildTarget(prove_subp)
    target.execute (extra_args="--limit-subp="+mk_loc_string (loc),
                    synchronous=False)

def on_show_unprovable_code(self):
    GPS.BuildTarget(show_unprovable_code).execute(synchronous=False)

if gnatprove:
  GPS.Menu.create(menu_prefix, ref = "Window", add_before = True)
  GPS.Menu.create(menu_prefix + "/" + prove_all, on_prove_all)
  GPS.Menu.create(menu_prefix + "/" + prove_root_project, on_prove_root_project)
  GPS.Menu.create(menu_prefix + "/" + prove_file, on_prove_file)
  GPS.Menu.create(menu_prefix + "/" + show_unprovable_code, on_show_unprovable_code)
  GPS.Contextual (prefix + "/" + prove_file).create(on_activate = on_prove_file)
  GPS.Contextual (prefix + "/" + prove_line).create(on_activate = on_prove_line)
  GPS.Contextual (prefix + "/" + prove_subp).create(
          on_activate = on_prove_subp, filter = is_subp_context)
  GPS.parse_xml(xml_gnatprove)
