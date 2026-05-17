function ok(res, data) {
    res.json({ ok: true, data });
}

function fail(res, status, code, message) {
    res.status(status).json({ ok: false, error: { code, message } });
}

module.exports = { ok, fail };
