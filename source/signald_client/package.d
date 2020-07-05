/**
Copyright: Copyright (c) 2020, Joakim Brännström. All rights reserved.
License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
Author: Joakim Brännström (joakim.brannstrom@gmx.com)
*/
module signald_client;

import std.json;
import std.socket;
import std.typecons : Nullable;
import std.algorithm : countUntil;
import std.array : empty;
import std.conv : to;
import logger = std.experimental.logger;

struct SignalDSocket {
    private {
        long responseIdNext;
        Socket sock;
        ubyte[] internalBuf;

        bool[ResponseId] waitingFor;
        Response[ResponseId] response;
    }
    const string metadata;

    this(string addr) {
        import std.path : expandTilde;

        sock = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        sock.connect(new UnixAddress(addr.expandTilde));
        metadata = this.readln;
    }

    ~this() {
        sock.close;
        sock = null;
    }

    /// Returns: the underlying socket to make it possible to e.g. change to
    /// non-blocking mode.
    Socket socket() {
        return sock;
    }

    void rawSend(const(char)[] s) {
        this.rawSend(cast(const(ubyte)[]) s);
    }

    void rawSend(const(ubyte)[] s) {
        sock.send(s);
    }

    ubyte[] rawRecv() @safe {
        ubyte[1024] buf;
        auto rlen = sock.receive(buf);
        if (rlen <= 0)
            return null;
        return buf[0 .. rlen].dup;
    }

    string readln() {
        internalBuf ~= rawRecv;
        const p = internalBuf.countUntil(10);
        if (p == -1)
            return null;
        auto s = internalBuf[0 .. p];
        internalBuf = internalBuf[p + 1 .. $];
        return cast(immutable(char)[]) s.idup;
    }

    /// Read from the socket and store any response messages that the socket is
    /// waiting for.
    void poll() {
        const s = readln;
        if (s.empty)
            return;

        try {
            auto j = parseJSON(s);
            ResponseId id;
            if (auto v = "id" in j) {
                id = ResponseId(v.str.to!long);
            } else {
                logger.tracef("unknown incoming: ", j);
                return;
            }

            if (auto v = id in waitingFor) {
                response[id] = Response(j);
                waitingFor.remove(id);
            }
        } catch (Exception e) {
            logger.trace(e.msg);
        }
    }

    /// Returns: all response that wait to be processed.
    ref Response[ResponseId] allResponse() return  {
        return response;
    }

    ResponseId send(Msg m) {
        const id = responseIdNext++;
        auto j = m.value;
        j["id"] = id;
        rawSend(j.toString ~ "\n");
        waitingFor[ResponseId(id)] = true;
        return ResponseId(id);
    }

    Nullable!Response recv(ResponseId id) {
        typeof(return) rval;
        if (auto v = id in response) {
            rval = *v;
            response.remove(id);
        }
        return rval;
    }
}

struct Msg {
    JSONValue value;
}

struct ResponseId {
    long value;
}

struct Response {
    JSONValue value;
}

/// Route response messages to the registered processor.
class Router {
    private {
        Process[ResponseId] routes;
    }

    void route(ResponseId id, Process p) {
        routes[id] = p;
    }

    void update(ref SignalDSocket sd) {
        foreach (r; sd.response.byKeyValue) {
            if (auto v = r.key in routes) {
                v.incoming(sd, r.value);
                routes.remove(r.key);
            }
        }
    }
}

/// Process one or more response messages.
interface Process {
    void incoming(ref SignalDSocket sd, Response m);

    /// If false is returned then it is removed.
    bool update(ref SignalDSocket sd);
}
