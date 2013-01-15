/*
 * Copyright (C) 2011-2012 Daiki Ueno <ueno@unixuser.org>
 * Copyright (C) 2011-2012 Red Hat, Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
using Gee;

namespace Kkc {
    enum ExprNodeType {
        ARRAY,
        SYMBOL,
        STRING
    }

    struct ExprNode {
        public ExprNodeType type;
        public LinkedList<ExprNode?> nodes;
        public string data;
        public ExprNode (ExprNodeType type) {
            this.type = type;
        }
    }

    class ExprReader : Object {
        public ExprNode read_symbol (string expr, ref int index) {
            var builder = new StringBuilder ();
            bool stop = false;
            unichar uc = '\0';
            while (!stop && expr.get_next_char (ref index, out uc)) {
                switch (uc) {
                case '\\':
                    if (expr.get_next_char (ref index, out uc)) {
                        builder.append_unichar (uc);
                    }
                    break;
                case '(': case ')': case '"': case ' ':
                    stop = true;
                    break;
                default:
                    builder.append_unichar (uc);
                    break;
                }
            }
            var node = ExprNode (ExprNodeType.SYMBOL);
            node.data = builder.str;
            return node;
        }

        public ExprNode? read_string (string expr, ref int index) {
            return_val_if_fail (index < expr.length && expr[index] == '"',
                                null);
            var builder = new StringBuilder ();
            index++;
            bool stop = false;
            unichar uc = '\0';
            while (!stop && expr.get_next_char (ref index, out uc)) {
                switch (uc) {
                case '\\':
                    if (expr.get_next_char (ref index, out uc)) {
                        switch (uc) {
                        case '0':
                            int num = 0;
                            while (expr.get_next_char (ref index, out uc)) {
                                if (uc < '0' || uc > '7')
                                    break;
                                num <<= 3;
                                num += (int) uc - '0';
                            }
                            index--;
                            uc = (unichar) num;
                            break;
                        case 'x':
                            int num = 0;
                            while (expr.get_next_char (ref index, out uc)) {
                                uc = uc.tolower ();
                                if (('0' <= uc && uc <= '9') ||
                                    ('a' <= uc && uc <= 'f')) {
                                    num <<= 4;
                                    if ('0' <= uc && uc <= '9') {
                                        num += (int) uc - '0';
                                    }
                                    else if ('a' <= uc && uc <= 'f') {
                                        num += (int) uc - 'a' + 10;
                                    }
                                }
                                else {
                                    break;
                                }
                            }
                            index--;
                            uc = (unichar) num;
                            break;
                        default:
                            break;
                        }
                        builder.append_unichar (uc);
                    }
                    break;
                case '\"':
                    stop = true;
                    break;
                default:
                    builder.append_unichar (uc);
                    break;
                }
            }
            var node = ExprNode (ExprNodeType.STRING);
            node.data = builder.str;
            return node;
        }

        public ExprNode? read_expr (string expr, ref int index) {
            return_val_if_fail (index < expr.length && expr[index] == '(',
                                null);
            var nodes = new LinkedList<ExprNode?> ();
            bool stop = false;
            index++;
            unichar uc = '\0';
            while (!stop && expr.get_next_char (ref index, out uc)) {
                switch (uc) {
                case ' ':
                    break;
                case ')':
                    index++;
                    stop = true;
                    break;
                case '(':
                    index--;
                    nodes.add (read_expr (expr, ref index));
                    break;
                case '"':
                    index--;
                    nodes.add (read_string (expr, ref index));
                    break;
                default:
                    index--;
                    nodes.add (read_symbol (expr, ref index));
                    break;
                }
            }
            var node = ExprNode (ExprNodeType.ARRAY);
            node.nodes = nodes;
            return node;
        }
    }

    class ExprEvaluator : Object {
        public string? eval (ExprNode node) {
            if (node.type == ExprNodeType.ARRAY) {
                var iter = node.nodes.list_iterator ();
                if (iter.first ()) {
                    var funcall = iter.get ();
                    if (funcall.type == ExprNodeType.SYMBOL) {
                        // FIXME support other functions in more extensible way
                        if (funcall.data == "concat") {
                            var builder = new StringBuilder ();
                            while (iter.next ()) {
                                var arg = iter.get ();
                                if (arg.type == ExprNodeType.STRING) {
                                    builder.append (arg.data);
                                }
                            }
                            return builder.str;
                        }
                        else if (funcall.data == "current-time-string") {
                            var datetime = new DateTime.now_local ();
                            return datetime.format ("%a, %d %b %Y %T %z");
                        }
                        else if (funcall.data == "pwd") {
                            return Environment.get_current_dir ();
                        }
                        else if (funcall.data == "kkc-version") {
                            return "%s/%s".printf (Config.PACKAGE_NAME,
                                                   Config.PACKAGE_VERSION);
                        }
                    }
                }
            }
            return null;
        }
    }
}
