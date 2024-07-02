# -*- coding: utf-8 -*-

import argparse


def get_args_parser():
    """
    prog : The name of the program (default: os.path.basename(sys.argv[0]))
    usage : The string describing the program usage (default: generated from arguments added to parser)
    description : Text to display before the argument help (by default, no text)
    epilog : Text to display after the argument help (by default, no text)
    parents : A list of ArgumentParser objects whose arguments should also be included
    formatter_class : A class for customizing the help output
    prefix_chars : The set of characters that prefix optional arguments (default: ‘-‘)
    fromfile_prefix_chars : The set of characters that prefix files from which additional arguments should be read (default: None)
    argument_default : The global default value for arguments (default: None)
    conflict_handler : The strategy for resolving conflicting optionals (usually unnecessary)
    add_help : Add a -h/--help option to the parser (default: True)
    allow_abbrev : Allows long options to be abbreviated if the abbreviation is unambiguous. (default: True)
    exit_on_error : Determines whether or not ArgumentParser exits with error info when an error occurs. (default: True)

    ArgumentParser(prog=None, usage=None, description=None, epilog=None, parents=[],
            formatter_class=argparse.HelpFormatter, prefix_chars='-',
            fromfile_prefix_chars=None, argument_default=None, conflict_handler='error',
            add_help=True, allow_abbrev=True, exit_on_error=True)
    """
    parser = argparse.ArgumentParser(description='args parser example.')

    """
    Name | Description | Values
    required | Indicate whether an argument is required or optional | True or False
    action | Specify how an argument should be handled | 'store', 'store_const', 'store_true', 'append', 'append_const', 'count', 'help', 'version'
    choices | Limit values to a specific set of choices | ['foo', 'bar'], range(1, 10), or Container instance
    const | Store a constant value
    default | Default value used when an argument is not provided | Defaults to None
    metavar | Alternate display name for the argument as shown in help
    type | Automatically convert an argument to the given type | int, float, argparse.FileType('w'), or callable function
    nargs | Number of times the argument can be used | int, '?', '*', or '+'
    dest | Specify the attribute name used in the result namespace,
    help | Help message for an argument

    add_argument(name or flags...[, action][, nargs][, const][, default][, type][, choices][, required][, help][, metavar][, dest]
    """

    """
    For positional argument actions, dest is normally supplied as the first argument to add_argument()
    required is an invalid argument for positionals
    """
    parser.add_argument('integers',  nargs='+', type=int, choices=range(0,10),
            help='an integer for the accumulator', metavar='N')

    """
    When parsing the command line, if the option string is encountered with no command-line argument following it,
    the value of const will be used. if the option is not specified, the value of default will be used.
    """
    parser.add_argument('--sum', dest='accumulate', action='store_const',
            const=sum, default=max,
            help='sum the integers (default: find the max)')

    return parser


if __name__ == "__main__":
    args_parser = get_args_parser()
    args = args_parser.parse_args()
    print(args.accumulate(args.integers))
