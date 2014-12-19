#!/usr/bin/env python

#---- standard library imports ----#
import sys

# version check
if(not (sys.hexversion >= 0x2050000)):
    sys.exit("\n\nplease use python version >= 2.5\n\n")

import string
import re
import math
import os
import time
import getopt
import zlib
import gzip
import codecs
import optparse
import collections
import ConfigParser
from collections import defaultdict


#--- log ---
def status(*args):
    """ write each argument to stderr, space separated, with a trailing newline """
    sys.stderr.write(" ".join([str(a) for a in args]) + "\n")

def error(error_string, terminate_program=True, current_frame=False):
    """Print error messages to stderr, optionally sys.exit"""

    if(current_frame == False):
        pretty_error_string = """

--------------------------------------------------------------------------------
                                       ERROR
--------------------------------------------------------------------------------
%s
--------------------------------------------------------------------------------

""" % (error_string)
    else:
        pretty_error_string = """

--------------------------------------------------------------------------------
                                       ERROR
--------------------------------------------------------------------------------
FILE: %s
LINE: %s
--------------------------------------------------------------------------------
%s
--------------------------------------------------------------------------------

""" % (current_frame.f_code.co_filename, current_frame.f_lineno, error_string)

    sys.stderr.write(pretty_error_string)

    if(terminate_program == True):
        sys.exit(1)








#--- util ---
def parse_cfg_args(arg_list):
    """Parse command-line style config settings to a dictionary.

    If you want to override configuration file values on the command
    line or set ones that were not set, this should make it simpler.
    Given a list in format [section.key=value, ...] return a
    dictionary in form { (section, key): value, ...}.

    So we might have:

    .. code-block:: python

      ['corpus.load=english-mz',
       'corpus.data_in=/home/user/corpora/ontonotes/data/']

    we would then return the dictionary:

    .. code-block:: python

      { ('corpus', 'load') : 'english-mz',
        ('corpus', 'data_in') : '/home/user/corpora/ontonotes/data/' }

    See also :func:`load_config` and :func:`load_options`

    """

    if not arg_list:
        return {}

    config_append = {}

    for arg in arg_list:
        if len(arg.split("=")) != 2 or len(arg.split("=")[0].split('.')) != 2:
            raise Exception("Invalid argument; not in form section.key=value : " + arg)

        key, value = arg.split("=")
        config_append[tuple(key.split("."))] = value

    return config_append



# section -> value -> (allowed_values, doc, required, section_required, allow_multiple)
__registered_config_options = defaultdict( dict )

def is_config_section_registered(section):
    return section in __registered_config_options

def is_config_registered(section, value, strict=False):
    if section not in __registered_config_options:
        return False
    return value in __registered_config_options[section] or (
        not strict and "__dynamic" in __registered_config_options[section])

def required_config_options(section):
    if not is_config_section_registered(section):
        return []
    return [value for value in __registered_config_options[section]
            if __registered_config_options[section][value][2]] # required

def required_config_sections():
    return [section for section in __registered_config_options if
            [True for value in __registered_config_options[section]
             if __registered_config_options[section][value][3]]] # section_required

def allowed_config_values(section, option):
    if not is_config_registered(section, option, strict=True):
        return []
    return __registered_config_options[section][option][0]

def allow_multiple_config_values(section, option):
    if not is_config_registered(section, option, strict=True):
        return []
    return __registered_config_options[section][option][4]

def print_config_docs(to_string=False):
    p = []
    p.append("")
    p.append("Allowed configuration arguments:")
    for section in sorted(__registered_config_options.iterkeys()):
        p.append("   Section " + section + ":")

        if section in required_config_sections():
            p[-1] += " (required)"

        for value, (allowed_values, doc, required, section_required, allow_multiple) in sorted(__registered_config_options[section].iteritems()):
            if value == "__dynamic":
                value = "note: other dynamically generated config options may be used"

            p.append("      " + value)
            if required:
                p[-1] += " (required)"

            if doc:
                p.append("         " + doc)
            if allowed_values:
                if allow_multiple:
                    p.append("         may be one or more of:")
                else:
                    p.append("         may be one of:")

                for allowed_value in allowed_values:
                    p.append("            " + allowed_value)
        p.append("")
    s = "\n".join(p)
    if to_string:
        return s
    else:
        on.common.log.status(s)

def register_config(section, value, allowed_values=[], doc=None, required=False, section_required=False, allow_multiple=False):
    """ make decorator so funcs can specify which config options they take.

    usage is:

    .. code-block:: python

      @register_config('corpus', 'load', 'specify which data to load to the db in the format lang-genre-source')
      def load_banks(config):
          ...

    The special value '__dynamic' means that some config values are
    created dynamically and we can't verify if a config argument is
    correct simply by seeing if it's on the list.  Documentation is
    also generated to this effect.

    If ``allowed_values`` is non-empty, then check to see that the
    setting the user chose is on the list.

    If ``allow_multiple`` is True, then when checking whether only
    allowed values are being given the key is first split on
    whitespace and then each component is tested.

    If ``required`` is True, then if the section exists it must
    specify this value.  If the section does not exist, it is free to
    ignore this value.  See ``section_required`` .

    If ``section_required`` is True, then issue an error if
    ``section`` is not defined by the user.  Often wanted in
    combination with ``required`` .

    """

    __registered_config_options[section][value] = (allowed_values, doc, required, section_required, allow_multiple)
    return lambda f: f

def load_options(parser=None, argv=[], positional_args=True):
    """ parses sys.argv, possibly exiting if there are mistakes

    If you set parser to a ConfigParser object, then you have control
    over the usage string and you can prepopulate it with options you
    intend to use.  But don't set a ``--config`` / ``-c`` option;
    load_options uses that to find a configuration file to load

    If a parser was passed in, we return ``(config, parser, [args])``.
    Otherwise we return ``(config, [args])``.  Args is only included
    if ``positional_args`` is True and there are positional arguments

    See :func:`load_config` for details on the ``--config`` option.

    """

    def is_config_appender(arg):
        return "." in arg and "=" in arg and arg.find(".") < arg.find("=")

    parser_passed_in=parser
    if not parser:
        parser = OptionParser()

    parser.add_option("-c", "--config", help="the path to a config file to read options from")

    if argv:
        options, args = parser.parse_args(argv)
    else:
        options, args = parser.parse_args()

    config = load_config(options.config, [a for a in args if is_config_appender(a)])

    other_args = [a for a in args if not is_config_appender(a)]

    return_list = [config]
    if parser_passed_in:
        return_list.append(options)
    if other_args:
        if positional_args:
            return_list.append(other_args)
        else:
            raise Exception("Arguments %s not understood" % other_args)
    else:
        if positional_args:
            raise Exception("This program expects one or more positional arguments that are missing")

    if len(return_list) == 1:
        return return_list[0]
    else:
        return tuple(return_list)


class FancyConfigParserError(Exception):
    """ raised by :class:`FancyConfigParser` when used improperly """

    def __init__(self, vals):
        Exception.__init__(self, 'Config usage must be in the form "config[\'section\', \'item\']". '
                           'Given something more like "config[%s]".' % (", ".join("%r"%v for v in vals)))


class FancyConfigParser(ConfigParser.SafeConfigParser):
    """ make a config parser with support for config[section, value]

    raises :class:`FancyConfigParserError` on improper usage.

    """

    def __getitem__(self, vals):
        try:
            section, item = vals
        except (ValueError, TypeError):
            raise FancyConfigParserError(vals)
        return self.get(section, item)


    def __setitem__(self, vals, value):
        try:
            section, item = vals
        except (ValueError, TypeError):
            raise FancyConfigParserError(vals)
        return self.set(section, item, value)

    def __delitem__(self, vals):
        try:
            section, item = vals
        except (ValueError, TypeError):
            raise FancyConfigParserError(vals)

        self.remove_option(section, item)

def load_config(cfg_name=None, config_append=[]):
    """ Load a configuration file to memory.

    The given configuration file name can be a full path, in which
    case we simply read that configuration file.  Otherwise, if you
    give 'myconfig' or something similar, we look in the current
    directory and the home directory.  We also look to see if files
    with this name and extension '.conf' exist.  So for 'myconfig' we
    would look in the following places:

     * ./myconfig
     * ./myconfig.conf
     * [home]/.myconfig
     * [home]/.myconfig.conf

    Once we find the configuration, we load it.  We also extend
    ConfigParser to support ``[]`` notation.  So you could look up key
    ``k`` in section ``s`` with ``config[s,k]``.  See
    :func:`FancyConfigParser` .

    If config_append is set we use :func:`parse_cfg_args` and add any
    values it creates to the config object.  These values override any
    previous ones.

    """

    config = FancyConfigParser()

    if cfg_name:
        config_locs = [cfg_name + '.conf',
                       os.path.expanduser('~/.' + cfg_name + '.conf'),
                       cfg_name,
                       os.path.expanduser('~/.' + cfg_name)]
        l = config.read(config_locs)
        if not l:
            raise Exception("Couldn't find config file.  Looked in:" +
                            "".join(["\n - " + c for c in config_locs]) +
                            "\nto no avail.")


    for (section, key_name), value in parse_cfg_args(config_append).iteritems():
        if not config.has_section(section):
            config.add_section(section)
        config.set(section, key_name, value)

    problems = []
    for section in config.sections():
        if not is_config_section_registered(section):
            status("Ignoring unknown configuration section", section)
            continue
        for option in config.options(section):
            if not is_config_registered(section, option):
                problems.append("Unknown configuration variable %s.%s" % (section, option))
                continue

            value = config.get(section, option)
            allowed = allowed_config_values(section, option)
            multiple = allow_multiple_config_values(section, option)

            values = value.split() if multiple else [value]
            for value in values:
                if allowed and not value in allowed:
                    problems.append("Illegal value '%s' for configuration variable %s.%s.  Permitted values are: %s" %
                                    (value, section, option, ", ".join(["'%s'" % x for x in allowed])))

        for option in required_config_options(section):
            if not config.has_option(section, option):
                problems.append("Required configuration variable %s.%s is absent" % (section, option))

    for section in required_config_sections():
        if not config.has_section(section):
            problems.append("Required configuration section %s is absent" % section)

    if problems:
        print_config_docs()

        status("Configuration Problems:")
        for problem in problems:
            status("  " + problem)

        sys.exit(-1)

    return config



def sopen(filename, mode="r"):
    """Open a file 'smartly'; understanding '-', '.gz', and normal files.

    If you have a command line argument to represent a filename,
    people often want to be able to put in standard input with a '-'
    or use gzipped (.gz and .bz2) files.  So you use :func:`sopen` in
    place of :func:`open`.

    Returns an open file.

    """

    if filename.endswith(".gz"):
        if mode=="r":
            mode = "rb"
        return gzip.open(filename, mode)
    elif filename.endswith(".bz2"):
        return bz2.BZ2File(filename, "r")
    elif filename == "-":
        if(mode != "r"):
            error("can open standard input for reading only")
        else:
            return sys.stdin
    else:
        return open(filename, mode)






def check_offsets(offsets):
  
  if offsets != 'null' and not '-' in offsets:
    raise Exception("The offset can be null or of the form a-b or a-b,c-d.")


  if offsets != 'null':
    if "," in offsets:
      for offset in offsets.split(","):
        bits = offset.split("-")
        from_offset = int(bits[0])
        to_offset = int(bits[1])

        assert from_offset < to_offset, "The character offsets should always be in increasing order [%s]" % (offsets)
    else:
        bits = offsets.split("-")
        from_offset = int(bits[0])
        to_offset = int(bits[1])

        assert from_offset < to_offset, "The character offsets should always be in increasing order [%s]" % (offsets)



def check_pipe_contents(pipe_filename):
  pipe_file = sopen(pipe_filename)

  for pipe_line in pipe_file:
    pipe_line = pipe_line.strip()
    bits = pipe_line.split("|")
    assert len(bits) == 19, "There should be exactly 19 columns in the pipe-delimited (.pipe) file"

    # check that the file name inside the file is the same as
    # the filename of the file
    
    assert os.path.splitext(bits[0])[0] == os.path.splitext(os.path.split(pipe_filename)[-1])[0], "The filename inside the .pipe file should match the name of the pipe file"

    check_offsets(bits[1])
    assert bits[3] in ['yes', 'no'], "Negation attribute value can only be yes or no. Found %s" % (bits[3])
    assert bits[5] in ['patient', 'family_member', 'other', 'donor_other'], "Subject class can be patient, family_member, other, or donor_other. Found %s" % (bits[5])
    assert bits[7] in ['no', 'yes'], "Uncertainty class can be yes or no. Found %s" % (bits[7])
    assert bits[9] in ['unmarked', 'increased', 'improved', 'worsened', 'resolved', 'decreased', 'changed'], "Course class can be unmarked, increased, improved, worsened, resolved, decreased, or changed. Found %s" % (bits[9])
    assert bits[11] in ['unmarked', 'moderate', 'severe', 'slight'], " can be unmarked, moderate, severe or slight. Found %s" % (bits[11])
    assert bits[13] in ['false', 'true'], "Conditional class can be true or false. Found %s" % (bits[13])
    assert bits[15] in ['false', 'true'], "Generic class can be true or false. Found %s" % (bits[15])
    check_offsets(bits[-1])





def check_run_dir(team_dir, run_dir):
  assert run_dir.startswith("run-")
  assert run_dir.split("-")[1].split(".")[0] in ['0', '1', '2'], "Please provide at most three runs, 0, 1 and 2"
  assert len(run_dir.split("-")[1].split(".")[1]) == 2, "Please make sure that the run version is between 00..99"
  assert int(run_dir.split("-")[1].split(".")[1]) < 100, "Please make sure that the run version is between 00..99"
  assert os.path.exists("%s/%s/data/test/discharge" % (team_dir, run_dir)), "Please make sure that the %s dir has the data/test/discharge under it"
  

  pipe_files = os.listdir("%s/%s/data/test/discharge/" % (team_dir, run_dir))
  assert len(pipe_files) == 100, "There should be exactly 100 .pipe files in each run"

  for pipe_file in pipe_files:
    assert os.path.splitext(pipe_file)[1] == ".pipe", "All the files in the run directory should be .pipe files"

    check_pipe_contents("%s/%s/data/test/discharge/%s" % (team_dir, run_dir, pipe_file))

        



def main():
    # total number of expected actual arguments, not counting the command itself
    required_number_of_args = 1

    o_parser = optparse.OptionParser(usage="""usage: %prog [options]

Description: 
  This program takes as argument, a top level directory containing upto
  Three runs for the SemEval-2015, Task 14 and raises exceptions if
  in case it finds some inconsistency in the organization or the data
  or values of attributes in the .pipe files."""
)
    o_parser.set_defaults(DEBUG=False)
    o_parser.set_defaults(VERBOSITY=False)
    o_parser.set_defaults(TEAM_ID="")

    o_parser.add_option("-d", "--debug", action="store_true", dest="DEBUG", help="Set debug mode on")
    o_parser.add_option("-v", "--verbosity", action="store", type="int", dest="VERBOSITY", help="Set verbosity level")
    o_parser.add_option("-t", "--team-id", action="store", dest="TEAM_ID", help="Your Team ID.")

    if(required_number_of_args > 0):
        c_config, o_options, o_args = load_options(parser=o_parser)
        if(len(o_args) != required_number_of_args):
            error("please specify %s arguments" % (required_number_of_args))
    else:
        c_config, o_options = load_options(parser=o_parser, positional_args=False)



    DEBUG = o_options.DEBUG
    VERBOSITY = o_options.VERBOSITY


    if(o_options.config != None):
        VERBOSITY = False
    else:
        pass


    legal_options = []
    if(legal_options != []
       and
       o_options.option not in legal_options):
        error("please specify one of %s options" % (" ".join(legal_options)))

    team_id = o_options.TEAM_ID


    if team_id == "":
      raise Exception("Please specify your Team ID using the -t|--team-id option")


    if(required_number_of_args > 0):
        top_level_dir = o_args[0]

        items_at_levels = []
        for root, dir, files in os.walk(top_level_dir):
          items_at_levels.append([root, dir, files])

        #for i in range(0, len(items_at_levels)):
        #  print i, items_at_levels[i]

        assert items_at_levels[0][0].rstrip("/").endswith("semeval-2015-task-14"), "Top level directory should be semeval-2015-task-14/"
        assert items_at_levels[0][1][0] == "submissions", "Top first sub-directory should be submissions"
        assert items_at_levels[1][1][0] == team_id, "The Team ID directory should match your Team ID"


        # check that the run directories match the format
        team_dir = items_at_levels[2][0]

        # check each run
        for run_dir in items_at_levels[2][1]:
          check_run_dir(team_dir, run_dir)
    
        print "\n\nSuccess! all the test passed.\n\n"
        


if __name__ == '__main__':
    main()
