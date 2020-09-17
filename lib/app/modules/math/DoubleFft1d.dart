import 'dart:convert';
import 'dart:math' as math;

import 'concurrency.dart';

enum Plans { SPLIT_RADIX, MIXED_RADIX, BLUESTEIN }

class DoubleFFt1d {
  int n;
  Concurrency concurrency = new Concurrency();
  List<int> factors = [4, 2, 3, 5];
  Plans plans;
  int nBluestein = 0;
  List<double> bk1 = [];
  List<double> bk2 = [];
  List<double> wtable = [];
  List<double> wtableR = [];
  int nw = 0;
  int nc = 0;
  List<int> ip = new List<int>();
  List<double> w = new List<double>();
  static final double pi = 3.14159265358979311599796346854418516;
  static final double twoPi = 6.28318530717958623199592693708837032;

  DoubleFFt1d(int n) {
    if (n < 1) {
      throw ("n must be greater than 0");
    }
    this.n = n;

    if (!concurrency.isPowerOf2(n)) {
      if (getReminder(n, factors) >= 211) {
        plans = Plans.BLUESTEIN;
        nBluestein = concurrency.nextPow2(n * 2 - 1);

        bk1 = new List<double>(2 * nBluestein);
        bk2 = new List<double>(2 * nBluestein);

        for (int i = 0; i < bk1.length; i++) {
          bk1[i] = 0;
        }

        for (int i = 0; i < bk2.length; i++) {
          bk2[i] = 0;
        }

        var newIp = 2 +
            (2 +
                    (1 <<
                        (math.log(nBluestein + 0.5) ~/ math.log(2)).toInt() ~/
                            2))
                .ceil()
                .toInt();

        this.ip = new List<int>(newIp);

        for (int i = 0; i < newIp; i++) {
          ip[i] = 0;
        }

        this.w = new List(nBluestein);

        int twon = 2 * nBluestein;

        nw = ip[0];

        if (twon > (nw << 2)) {
          nw = twon >> 2;
          makewt(nw);
        }
        nc = ip[1];

        if (n > (nc << 2)) {
          nc = n >> 2;
          makect(nc, w, nw);
        }

        bluesteini();
      }
    } else {
      plans = Plans.MIXED_RADIX;
      wtable = new List<double>(4 * n + 15);
      wtableR = new List<double>(2 * n + 15);

      cffti();
      rffti();
    }

    print('PLANS -> $plans');
  }
  int getReminder(int n, List<int> factors) {
    int reminder = n;

    if (n <= 0) {
      throw ("n must be positive integer");
    }

    for (int i = 0; i < factors.length && reminder != 1; i++) {
      int factor = factors[i];
      while ((reminder % factor) == 0) {
        reminder ~/= factor;
      }
    }
    return reminder;
  }

  void cffti() {
    if (n == 1) return;

    final int twon = 2 * n;
    final int fourn = 4 * n;
    double argh;
    int idot, ntry = 0, i, j;
    double argld;
    int i1, k1, l1, l2, ib;
    double fi;
    int ld, ii, nf, ip, nl, nq, nr;
    double arg;
    int ido, ipm;

    nl = n;
    nf = 0;
    j = 0;

    factorize_loop:
    while (true) {
      j++;
      if (j <= 4)
        ntry = factors[j - 1];
      else
        ntry += 2;
      do {
        nq = nl ~/ ntry;
        nr = nl - ntry * nq;
        if (nr != 0) continue factorize_loop;
        nf++;
        wtable[nf + 1 + fourn] = ntry.toDouble();
        nl = nq;
        if (ntry == 2 && nf != 1) {
          for (i = 2; i <= nf; i++) {
            ib = nf - i + 2;
            int idx = ib + fourn;
            wtable[idx + 1] = wtable[idx];
          }
          wtable[2 + fourn] = 2;
        }
      } while (nl != 1);
      break factorize_loop;
    }
    wtable[fourn] = n.toDouble();
    wtable[1 + fourn] = nf.toDouble();
    argh = twoPi / n.toDouble();
    i = 1;
    l1 = 1;
    for (k1 = 1; k1 <= nf; k1++) {
      ip = wtable[k1 + 1 + fourn].toInt();
      ld = 0;
      l2 = l1 * ip;
      ido = n ~/ l2;
      idot = ido + ido + 2;
      ipm = ip - 1;
      for (j = 1; j <= ipm; j++) {
        i1 = i;
        wtable[i - 1 + twon] = 1;
        wtable[i + twon] = 0;
        ld += l1;
        fi = 0;
        argld = ld * argh;
        for (ii = 4; ii <= idot; ii += 2) {
          i += 2;
          fi += 1;
          arg = fi * argld;
          int idx = i + twon;
          wtable[idx - 1] = math.cos(arg);
          wtable[idx] = math.sin(arg);
        }
        if (ip > 5) {
          int idx1 = i1 + twon;
          int idx2 = i + twon;
          wtable[idx1 - 1] = wtable[idx2 - 1];
          wtable[idx1] = wtable[idx2];
        }
      }
      l1 = l2;
    }
  }

  void rffti() {
    if (n == 1) return;
    final int twon = 2 * n;
    double argh;
    int ntry = 0, i, j;
    double argld;
    int k1, l1, l2, ib;
    double fi;
    int ld, ii, nf, ip, nl, by, nq, nr;
    double arg;
    int ido, ipm;
    int nfm1;

    nl = n;
    nf = 0;
    j = 0;

    factorize_loop:
    while (true) {
      ++j;
      if (j <= 4)
        ntry = factors[j - 1];
      else
        ntry += 2;
      do {
        nq = nl ~/ ntry;
        nr = nl - ntry * nq;
        if (nr != 0) continue factorize_loop;
        ++nf;
        wtableR[nf + 1 + twon] = ntry.toDouble();

        nl = nq;
        if (ntry == 2 && nf != 1) {
          for (i = 2; i <= nf; i++) {
            ib = nf - i + 2;
            int idx = ib + twon;
            wtableR[idx + 1] = wtableR[idx];
          }
          wtableR[2 + twon] = 2;
        }
      } while (nl != 1);
      break factorize_loop;
    }
    wtableR[twon] = n.toDouble();
    wtableR[1 + twon] = nf.toDouble();
    argh = twoPi / (n);
    by = 0;
    nfm1 = nf - 1;
    l1 = 1;
    if (nfm1 == 0) return;
    for (k1 = 1; k1 <= nfm1; k1++) {
      ip = wtableR[k1 + 1 + twon].toInt();
      ld = 0;
      l2 = l1 * ip;
      ido = n ~/ l2;
      ipm = ip - 1;
      for (j = 1; j <= ipm; ++j) {
        ld += l1;
        i = by;
        argld = ld * argh.toDouble();

        fi = 0;
        for (ii = 3; ii <= ido; ii += 2) {
          i += 2;
          fi += 1;
          arg = fi * argld;
          int idx = i + n;
          wtableR[idx - 2] = math.cos(arg);
          wtableR[idx - 1] = math.sin(arg);
        }
        by += ido;
      }
      l1 = l2;
    }
  }

  void bluesteini() {
    int k = 0;
    double arg;
    double pi_n = pi / n;
    bk1[0] = 1;
    bk1[1] = 0;
    for (int i = 1; i < n; i++) {
      k += 2 * i - 1;
      if (k >= 2 * n) k -= 2 * n;
      arg = pi_n * k;
      bk1[2 * i] = math.cos(arg);
      bk1[2 * i + 1] = math.sin(arg);
    }
    double scale = 1.0 / nBluestein;
    bk2[0] = bk1[0] * scale;
    bk2[1] = bk1[1] * scale;
    for (int i = 2; i < 2 * n; i += 2) {
      bk2[i] = bk1[i] * scale;
      bk2[i + 1] = bk1[i + 1] * scale;
      bk2[2 * nBluestein - i] = bk2[i];
      bk2[2 * nBluestein - i + 1] = bk2[i + 1];
    }
    cftbsub(2 * nBluestein, bk2, 0, ip, nw, w);
  }

  void makewt(int nw) {
    int j, nwh, nw0, nw1;
    double delta, wn4r, wk1r, wk1i, wk3r, wk3i;
    double delta2, deltaj, deltaj3;

    ip[0] = nw;
    ip[1] = 1;

    if (nw > 2) {
      nwh = nw >> 1;
      delta = 0.785398163397448278999490867136046290 / nwh;
      delta2 = delta * 2;
      wn4r = math.cos(delta * nwh);

      w[0] = 1;
      w[1] = wn4r;

      if (nwh == 4) {
        w[2] = math.cos(delta2);
        w[3] = math.sin(delta2);
      } else if (nwh > 4) {
        makeipt(nw);

        w[2] = 0.5 / math.cos(delta2);
        w[3] = 0.5 / math.cos(delta * 6);
        for (j = 4; j < nwh; j += 4) {
          deltaj = delta * j;
          deltaj3 = 3 * deltaj;
          w[j] = math.cos(deltaj);
          w[j + 1] = math.sin(deltaj);
          w[j + 2] = math.cos(deltaj3);
          w[j + 3] = -math.sin(deltaj3);
        }
      }

      nw0 = 0;
      while (nwh > 2) {
        nw1 = nw0 + nwh;
        nwh >>= 1;
        w[nw1] = 1;
        w[nw1 + 1] = wn4r;
        if (nwh == 4) {
          wk1r = w[nw0 + 4];
          wk1i = w[nw0 + 5];
          w[nw1 + 2] = wk1r;
          w[nw1 + 3] = wk1i;
        } else if (nwh > 4) {
          wk1r = w[nw0 + 4];
          wk3r = w[nw0 + 6];
          w[nw1 + 2] = 0.5 / wk1r;
          w[nw1 + 3] = 0.5 / wk3r;
          for (j = 4; j < nwh; j += 4) {
            int idx1 = nw0 + 2 * j;
            int idx2 = nw1 + j;
            wk1r = w[idx1];
            wk1i = w[idx1 + 1];
            wk3r = w[idx1 + 2];
            wk3i = w[idx1 + 3];
            w[idx2] = wk1r;
            w[idx2 + 1] = wk1i;
            w[idx2 + 2] = wk3r;
            w[idx2 + 3] = wk3i;
          }
        }
        nw0 = nw1;
      }
    }
  }

  void makect(int nc, List<double> c, int startc) {
    int j, nch;
    double delta, deltaj;

    ip[1] = nc;

    if (nc > 1) {
      nch = nc >> 1;
      delta = 0.785398163397448278999490867136046290 / nch;
      c[startc] = math.cos(delta * nch);
      c[startc + nch] = 0.5 * c[startc];
      for (j = 1; j < nch; j++) {
        deltaj = delta * j;
        c[startc + j] = 0.5 * math.cos(deltaj);
        c[startc + nc - j] = 0.5 * math.sin(deltaj);
      }
    }
  }

  void makeipt(int nw) {
    int j, l, m, m2, p, q;

    ip[2] = 0;
    ip[3] = 16;
    m = 2;
    for (l = nw; l > 32; l >>= 2) {
      m2 = m << 1;
      q = m2 << 3;
      for (j = m; j < m2; j++) {
        p = ip[j] << 2;
        ip[m + j] = p;
        ip[m2 + j] = p + q;
      }
      m = m2;
    }
  }

  void realForward(List<double> a, int offa) {
    if (n == 1) return;

    switch (plans) {
      case Plans.SPLIT_RADIX:
        double xi;

        if (n > 4) {
          cftfsub(n, a, offa, ip, nw, w);
          rftfsub(n, a, offa, nc, w, nw);
        } else if (n == 4) {
          cftx020(a, offa);
        }
        xi = a[offa] - a[offa + 1];
        a[offa] += a[offa + 1];
        a[offa + 1] = xi;
        break;

      case Plans.MIXED_RADIX:
        rfftf(a, offa);
        for (int k = n - 1; k >= 2; k--) {
          int idx = offa + k;
          double tmp = a[idx];
          a[idx] = a[idx - 1];
          a[idx - 1] = tmp;
        }
        break;
      case Plans.BLUESTEIN:
        bluesteinRealForward(a, offa);
        break;
    }

    // bluesteinRealForward(a, 0);
  }

  void bluesteinRealForward(List<double> a, int offa) {
    List<double> ak = [];

    ak = new List<double>(2 * nBluestein);

    for (int i = 0; i < ak.length; i++) {
      ak[i] = 0;
    }

    int nthreads = concurrency.getNumberOfThreads();

    if ((nthreads > 1) && (n > concurrency.getThreadsBeginN1DFFT2Threads())) {
      nthreads = 2;

      if ((nthreads >= 4) &&
          (n > concurrency.getThreadsBeginN1DFFT4Threads())) {
        nthreads = 4;
      }

      int k = n ~/ nthreads;

      for (int i = 0; i < nthreads; i++) {
        final int firstIdx = i * k;

        final int lastIdx = (i == (nthreads - 1)) ? n : firstIdx + k;

        for (int i = firstIdx; i < lastIdx; i++) {
          int idx1 = 2 * i;
          int idx2 = idx1 + 1;
          int idx3 = offa + i;
          ak[idx1] = a[idx3] * bk1[idx1];
          ak[idx2] = -a[idx3] * bk1[idx2];
        }
      }

      cftbsub((2 * nBluestein), ak, 0, ip, nw, w);

      k = nBluestein ~/ nthreads;

      for (int i = 0; i < nthreads; i++) {
        final int firstIdx = i * k;
        final int lastIdx = (i == (nthreads - 1)) ? nBluestein : firstIdx + k;

        for (int i = firstIdx; i < lastIdx; i++) {
          int idx1 = 2 * i;
          int idx2 = idx1 + 1;
          double im = -ak[idx1] * bk2[idx2] + ak[idx2] * bk2[idx1];
          ak[idx1] = ak[idx1] * bk2[idx1] + ak[idx2] * bk2[idx2];
          ak[idx2] = im;
        }
      }
    } else {
      for (int i = 0; i < n; i++) {
        int idx1 = 2 * i;
        int idx2 = idx1 + 1;
        int idx3 = offa + i;
        ak[idx1] = a[idx3] * bk1[idx1];
        ak[idx2] = a[idx3] * bk1[idx2];
      }

      cftbsub((2 * nBluestein), ak, 0, ip, nw, w);

      for (int i = 0; i < nBluestein; i++) {
        int idx1 = 2 * i;
        int idx2 = idx1 + 1;
        double im = -ak[idx1] * bk2[idx2] + ak[idx2] * bk2[idx1];
        ak[idx1] = ak[idx1] * bk2[idx1] + ak[idx2] * bk2[idx2];
        ak[idx2] = im;
      }
    }

    cftfsub(2 * nBluestein, ak, 0, ip, nw, w);

    if (n % 2 == 0) {
      a[offa] = bk1[0] * ak[0] + bk1[1] * ak[1];
      a[offa + 1] = bk1[n] * ak[n] + bk1[n + 1] * ak[n + 1];
      for (int i = 1; i < n / 2; i++) {
        int idx1 = 2 * i;
        int idx2 = idx1 + 1;
        a[offa + idx1] = bk1[idx1] * ak[idx1] + bk1[idx2] * ak[idx2];
        a[offa + idx2] = -bk1[idx2] * ak[idx1] + bk1[idx1] * ak[idx2];
      }
    } else {
      a[offa] = bk1[0] * ak[0] + bk1[1] * ak[1];
      a[offa + 1] = -bk1[n] * ak[n - 1] + bk1[n - 1] * ak[n];
      for (int i = 1; i < (n - 1) / 2; i++) {
        int idx1 = 2 * i;
        int idx2 = idx1 + 1;
        a[offa + idx1] = bk1[idx1] * ak[idx1] + bk1[idx2] * ak[idx2];
        a[offa + idx2] = -bk1[idx2] * ak[idx1] + bk1[idx1] * ak[idx2];
      }
      a[offa + n - 1] = bk1[n - 1] * ak[n - 1] + bk1[n] * ak[n];
    }
  }

  void rfftf(final List<double> a, final int offa) {
    if (n == 1) return;
    int l1, l2, na, kh, nf, ip, iw, ido, idl1;

    final List<double> ch = new List<double>(n);
    final int twon = 2 * n;
    nf = wtableR[1 + twon].toInt();
    na = 1;
    l2 = n;
    iw = twon - 1;
    for (int k1 = 1; k1 <= nf; ++k1) {
      kh = nf - k1;
      ip = wtableR[kh + 2 + twon].toInt();
      l1 = l2 ~/ ip;
      ido = n ~/ l2;
      idl1 = ido * l1;
      iw -= (ip - 1) * ido;
      na = 1 - na;
      switch (ip) {
        case 2:
          if (na == 0) {
            radf2(ido, l1, a, offa, ch, 0, iw);
          } else {
            radf2(ido, l1, ch, 0, a, offa, iw);
          }
          break;
        case 3:
          if (na == 0) {
            radf3(ido, l1, a, offa, ch, 0, iw);
          } else {
            radf3(ido, l1, ch, 0, a, offa, iw);
          }
          break;
        case 4:
          if (na == 0) {
            radf4(ido, l1, a, offa, ch, 0, iw);
          } else {
            radf4(ido, l1, ch, 0, a, offa, iw);
          }
          break;
        case 5:
          if (na == 0) {
            radf5(ido, l1, a, offa, ch, 0, iw);
          } else {
            radf5(ido, l1, ch, 0, a, offa, iw);
          }
          break;
        default:
          if (ido == 1) na = 1 - na;
          if (na == 0) {
            radfg(ido, ip, l1, idl1, a, offa, ch, 0, iw);
            na = 1;
          } else {
            radfg(ido, ip, l1, idl1, ch, 0, a, offa, iw);
            na = 0;
          }
          break;
      }
      l2 = l1;
    }
    if (na == 1) return;
    // System.arraycopy(ch, 0, a, offa, n);
  }

  void radf2(
      final int ido,
      final int l1,
      final List<double> by,
      final int in_off,
      final List<double> out,
      final int out_off,
      final int offset) {
    int i, ic, idx0, idx1, idx2, idx3, idx4;
    double t1i, t1r, w1r, w1i;
    int iw1;
    iw1 = offset;
    idx0 = l1 * ido;
    idx1 = 2 * ido;
    for (int k = 0; k < l1; k++) {
      int oidx1 = out_off + k * idx1;
      int oidx2 = oidx1 + idx1 - 1;
      int iidx1 = in_off + k * ido;
      int iidx2 = iidx1 + idx0;

      double i1r = by[iidx1];
      double i2r = by[iidx2];

      out[oidx1] = i1r + i2r;
      out[oidx2] = i1r - i2r;
    }
    if (ido < 2) return;
    if (ido != 2) {
      for (int k = 0; k < l1; k++) {
        idx1 = k * ido;
        idx2 = 2 * idx1;
        idx3 = idx2 + ido;
        idx4 = idx1 + idx0;
        for (i = 2; i < ido; i += 2) {
          ic = ido - i;
          int widx1 = i - 1 + iw1;
          int oidx1 = out_off + i + idx2;
          int oidx2 = out_off + ic + idx3;
          int iidx1 = in_off + i + idx1;
          int iidx2 = in_off + i + idx4;

          double a1i = by[iidx1 - 1];
          double a1r = by[iidx1];
          double a2i = by[iidx2 - 1];
          double a2r = by[iidx2];

          w1r = wtableR[widx1 - 1];
          w1i = wtableR[widx1];

          t1r = w1r * a2i + w1i * a2r;
          t1i = w1r * a2r - w1i * a2i;

          out[oidx1] = a1r + t1i;
          out[oidx1 - 1] = a1i + t1r;

          out[oidx2] = t1i - a1r;
          out[oidx2 - 1] = a1i - t1r;
        }
      }
      if (ido % 2 == 1) return;
    }
    idx2 = 2 * idx1;
    for (int k = 0; k < l1; k++) {
      idx1 = k * ido;
      int oidx1 = out_off + idx2 + ido;
      int iidx1 = in_off + ido - 1 + idx1;

      out[oidx1] = -by[iidx1 + idx0];
      out[oidx1 - 1] = by[iidx1];
    }
  }

  void radf3(
      final int ido,
      final int l1,
      final List<double> by,
      final int in_off,
      final List<double> out,
      final int out_off,
      final int offset) {
    final double taur = -0.5;
    final double taui = 0.866025403784438707610604524234076962;
    int i, ic;
    double ci2, di2, di3, cr2, dr2, dr3, ti2, ti3, tr2, tr3, w1r, w2r, w1i, w2i;
    int iw1, iw2;
    iw1 = offset;
    iw2 = iw1 + ido;

    int idx0 = l1 * ido;
    for (int k = 0; k < l1; k++) {
      int idx1 = k * ido;
      int idx3 = 2 * idx0;
      int idx4 = (3 * k + 1) * ido;
      int iidx1 = in_off + idx1;
      int iidx2 = iidx1 + idx0;
      int iidx3 = iidx1 + idx3;
      double i1r = by[iidx1];
      double i2r = by[iidx2];
      double i3r = by[iidx3];
      cr2 = i2r + i3r;
      out[out_off + 3 * idx1] = i1r + cr2;
      out[out_off + idx4 + ido] = taui * (i3r - i2r);
      out[out_off + ido - 1 + idx4] = i1r + taur * cr2;
    }
    if (ido == 1) return;
    for (int k = 0; k < l1; k++) {
      int idx3 = k * ido;
      int idx4 = 3 * idx3;
      int idx5 = idx3 + idx0;
      int idx6 = idx5 + idx0;
      int idx7 = idx4 + ido;
      int idx8 = idx7 + ido;
      for (i = 2; i < ido; i += 2) {
        ic = ido - i;
        int widx1 = i - 1 + iw1;
        int widx2 = i - 1 + iw2;

        w1r = wtableR[widx1 - 1];
        w1i = wtableR[widx1];
        w2r = wtableR[widx2 - 1];
        w2i = wtableR[widx2];

        int idx9 = in_off + i;
        int idx10 = out_off + i;
        int idx11 = out_off + ic;
        int iidx1 = idx9 + idx3;
        int iidx2 = idx9 + idx5;
        int iidx3 = idx9 + idx6;

        double i1i = by[iidx1 - 1];
        double i1r = by[iidx1];
        double i2i = by[iidx2 - 1];
        double i2r = by[iidx2];
        double i3i = by[iidx3 - 1];
        double i3r = by[iidx3];

        dr2 = w1r * i2i + w1i * i2r;
        di2 = w1r * i2r - w1i * i2i;
        dr3 = w2r * i3i + w2i * i3r;
        di3 = w2r * i3r - w2i * i3i;
        cr2 = dr2 + dr3;
        ci2 = di2 + di3;
        tr2 = i1i + taur * cr2;
        ti2 = i1r + taur * ci2;
        tr3 = taui * (di2 - di3);
        ti3 = taui * (dr3 - dr2);

        int oidx1 = idx10 + idx4;
        int oidx2 = idx11 + idx7;
        int oidx3 = idx10 + idx8;

        out[oidx1 - 1] = i1i + cr2;
        out[oidx1] = i1r + ci2;
        out[oidx2 - 1] = tr2 - tr3;
        out[oidx2] = ti3 - ti2;
        out[oidx3 - 1] = tr2 + tr3;
        out[oidx3] = ti2 + ti3;
      }
    }
  }

  void radf4(
      final int ido,
      final int l1,
      final List<double> by,
      final int in_off,
      final List<double> out,
      final int out_off,
      final int offset) {
    final double hsqt2 = 0.707106781186547572737310929369414225;
    int i, ic;
    double ci2,
        ci3,
        ci4,
        cr2,
        cr3,
        cr4,
        ti1,
        ti2,
        ti3,
        ti4,
        tr1,
        tr2,
        tr3,
        tr4,
        w1r,
        w1i,
        w2r,
        w2i,
        w3r,
        w3i;
    int iw1, iw2, iw3;
    iw1 = offset;
    iw2 = offset + ido;
    iw3 = iw2 + ido;
    int idx0 = l1 * ido;
    for (int k = 0; k < l1; k++) {
      int idx1 = k * ido;
      int idx2 = 4 * idx1;
      int idx3 = idx1 + idx0;
      int idx4 = idx3 + idx0;
      int idx5 = idx4 + idx0;
      int idx6 = idx2 + ido;
      double i1r = by[in_off + idx1];
      double i2r = by[in_off + idx3];
      double i3r = by[in_off + idx4];
      double i4r = by[in_off + idx5];

      tr1 = i2r + i4r;
      tr2 = i1r + i3r;

      int oidx1 = out_off + idx2;
      int oidx2 = out_off + idx6 + ido;

      out[oidx1] = tr1 + tr2;
      out[oidx2 - 1 + ido + ido] = tr2 - tr1;
      out[oidx2 - 1] = i1r - i3r;
      out[oidx2] = i4r - i2r;
    }
    if (ido < 2) return;
    if (ido != 2) {
      for (int k = 0; k < l1; k++) {
        int idx1 = k * ido;
        int idx2 = idx1 + idx0;
        int idx3 = idx2 + idx0;
        int idx4 = idx3 + idx0;
        int idx5 = 4 * idx1;
        int idx6 = idx5 + ido;
        int idx7 = idx6 + ido;
        int idx8 = idx7 + ido;
        for (i = 2; i < ido; i += 2) {
          ic = ido - i;
          int widx1 = i - 1 + iw1;
          int widx2 = i - 1 + iw2;
          int widx3 = i - 1 + iw3;
          w1r = wtableR[widx1 - 1];
          w1i = wtableR[widx1];
          w2r = wtableR[widx2 - 1];
          w2i = wtableR[widx2];
          w3r = wtableR[widx3 - 1];
          w3i = wtableR[widx3];

          int idx9 = in_off + i;
          int idx10 = out_off + i;
          int idx11 = out_off + ic;
          int iidx1 = idx9 + idx1;
          int iidx2 = idx9 + idx2;
          int iidx3 = idx9 + idx3;
          int iidx4 = idx9 + idx4;

          double i1i = by[iidx1 - 1];
          double i1r = by[iidx1];
          double i2i = by[iidx2 - 1];
          double i2r = by[iidx2];
          double i3i = by[iidx3 - 1];
          double i3r = by[iidx3];
          double i4i = by[iidx4 - 1];
          double i4r = by[iidx4];

          cr2 = w1r * i2i + w1i * i2r;
          ci2 = w1r * i2r - w1i * i2i;
          cr3 = w2r * i3i + w2i * i3r;
          ci3 = w2r * i3r - w2i * i3i;
          cr4 = w3r * i4i + w3i * i4r;
          ci4 = w3r * i4r - w3i * i4i;
          tr1 = cr2 + cr4;
          tr4 = cr4 - cr2;
          ti1 = ci2 + ci4;
          ti4 = ci2 - ci4;
          ti2 = i1r + ci3;
          ti3 = i1r - ci3;
          tr2 = i1i + cr3;
          tr3 = i1i - cr3;

          int oidx1 = idx10 + idx5;
          int oidx2 = idx11 + idx6;
          int oidx3 = idx10 + idx7;
          int oidx4 = idx11 + idx8;

          out[oidx1 - 1] = tr1 + tr2;
          out[oidx4 - 1] = tr2 - tr1;
          out[oidx1] = ti1 + ti2;
          out[oidx4] = ti1 - ti2;
          out[oidx3 - 1] = ti4 + tr3;
          out[oidx2 - 1] = tr3 - ti4;
          out[oidx3] = tr4 + ti3;
          out[oidx2] = tr4 - ti3;
        }
      }
      if (ido % 2 == 1) return;
    }
    for (int k = 0; k < l1; k++) {
      int idx1 = k * ido;
      int idx2 = 4 * idx1;
      int idx3 = idx1 + idx0;
      int idx4 = idx3 + idx0;
      int idx5 = idx4 + idx0;
      int idx6 = idx2 + ido;
      int idx7 = idx6 + ido;
      int idx8 = idx7 + ido;
      int idx9 = in_off + ido;
      int idx10 = out_off + ido;

      double i1i = by[idx9 - 1 + idx1];
      double i2i = by[idx9 - 1 + idx3];
      double i3i = by[idx9 - 1 + idx4];
      double i4i = by[idx9 - 1 + idx5];

      ti1 = -hsqt2 * (i2i + i4i);
      tr1 = hsqt2 * (i2i - i4i);

      out[idx10 - 1 + idx2] = tr1 + i1i;
      out[idx10 - 1 + idx7] = i1i - tr1;
      out[out_off + idx6] = ti1 - i3i;
      out[out_off + idx8] = ti1 + i3i;
    }
  }

  void radf5(
      final int ido,
      final int l1,
      final List<double> by,
      final int in_off,
      final List<double> out,
      final int out_off,
      final int offset) {
    final double tr11 = 0.309016994374947451262869435595348477;
    final double ti11 = 0.951056516295153531181938433292089030;
    final double tr12 = -0.809016994374947340240566973079694435;
    final double ti12 = 0.587785252292473248125759255344746634;
    int i, ic;
    double ci2,
        di2,
        ci4,
        ci5,
        di3,
        di4,
        di5,
        ci3,
        cr2,
        cr3,
        dr2,
        dr3,
        dr4,
        dr5,
        cr5,
        cr4,
        ti2,
        ti3,
        ti5,
        ti4,
        tr2,
        tr3,
        tr4,
        tr5,
        w1r,
        w1i,
        w2r,
        w2i,
        w3r,
        w3i,
        w4r,
        w4i;
    int iw1, iw2, iw3, iw4;
    iw1 = offset;
    iw2 = iw1 + ido;
    iw3 = iw2 + ido;
    iw4 = iw3 + ido;

    int idx0 = l1 * ido;
    for (int k = 0; k < l1; k++) {
      int idx1 = k * ido;
      int idx2 = 5 * idx1;
      int idx3 = idx2 + ido;
      int idx4 = idx3 + ido;
      int idx5 = idx4 + ido;
      int idx6 = idx5 + ido;
      int idx7 = idx1 + idx0;
      int idx8 = idx7 + idx0;
      int idx9 = idx8 + idx0;
      int idx10 = idx9 + idx0;
      int idx11 = out_off + ido - 1;

      double i1r = by[in_off + idx1];
      double i2r = by[in_off + idx7];
      double i3r = by[in_off + idx8];
      double i4r = by[in_off + idx9];
      double i5r = by[in_off + idx10];

      cr2 = i5r + i2r;
      ci5 = i5r - i2r;
      cr3 = i4r + i3r;
      ci4 = i4r - i3r;

      out[out_off + idx2] = i1r + cr2 + cr3;
      out[idx11 + idx3] = i1r + tr11 * cr2 + tr12 * cr3;
      out[out_off + idx4] = ti11 * ci5 + ti12 * ci4;
      out[idx11 + idx5] = i1r + tr12 * cr2 + tr11 * cr3;
      out[out_off + idx6] = ti12 * ci5 - ti11 * ci4;
    }
    if (ido == 1) return;
    for (int k = 0; k < l1; ++k) {
      int idx1 = k * ido;
      int idx2 = 5 * idx1;
      int idx3 = idx2 + ido;
      int idx4 = idx3 + ido;
      int idx5 = idx4 + ido;
      int idx6 = idx5 + ido;
      int idx7 = idx1 + idx0;
      int idx8 = idx7 + idx0;
      int idx9 = idx8 + idx0;
      int idx10 = idx9 + idx0;
      for (i = 2; i < ido; i += 2) {
        int widx1 = i - 1 + iw1;
        int widx2 = i - 1 + iw2;
        int widx3 = i - 1 + iw3;
        int widx4 = i - 1 + iw4;
        w1r = wtableR[widx1 - 1];
        w1i = wtableR[widx1];
        w2r = wtableR[widx2 - 1];
        w2i = wtableR[widx2];
        w3r = wtableR[widx3 - 1];
        w3i = wtableR[widx3];
        w4r = wtableR[widx4 - 1];
        w4i = wtableR[widx4];

        ic = ido - i;
        int idx15 = in_off + i;
        int idx16 = out_off + i;
        int idx17 = out_off + ic;

        int iidx1 = idx15 + idx1;
        int iidx2 = idx15 + idx7;
        int iidx3 = idx15 + idx8;
        int iidx4 = idx15 + idx9;
        int iidx5 = idx15 + idx10;

        double i1i = by[iidx1 - 1];
        double i1r = by[iidx1];
        double i2i = by[iidx2 - 1];
        double i2r = by[iidx2];
        double i3i = by[iidx3 - 1];
        double i3r = by[iidx3];
        double i4i = by[iidx4 - 1];
        double i4r = by[iidx4];
        double i5i = by[iidx5 - 1];
        double i5r = by[iidx5];

        dr2 = w1r * i2i + w1i * i2r;
        di2 = w1r * i2r - w1i * i2i;
        dr3 = w2r * i3i + w2i * i3r;
        di3 = w2r * i3r - w2i * i3i;
        dr4 = w3r * i4i + w3i * i4r;
        di4 = w3r * i4r - w3i * i4i;
        dr5 = w4r * i5i + w4i * i5r;
        di5 = w4r * i5r - w4i * i5i;

        cr2 = dr2 + dr5;
        ci5 = dr5 - dr2;
        cr5 = di2 - di5;
        ci2 = di2 + di5;
        cr3 = dr3 + dr4;
        ci4 = dr4 - dr3;
        cr4 = di3 - di4;
        ci3 = di3 + di4;

        tr2 = i1i + tr11 * cr2 + tr12 * cr3;
        ti2 = i1r + tr11 * ci2 + tr12 * ci3;
        tr3 = i1i + tr12 * cr2 + tr11 * cr3;
        ti3 = i1r + tr12 * ci2 + tr11 * ci3;
        tr5 = ti11 * cr5 + ti12 * cr4;
        ti5 = ti11 * ci5 + ti12 * ci4;
        tr4 = ti12 * cr5 - ti11 * cr4;
        ti4 = ti12 * ci5 - ti11 * ci4;

        int oidx1 = idx16 + idx2;
        int oidx2 = idx17 + idx3;
        int oidx3 = idx16 + idx4;
        int oidx4 = idx17 + idx5;
        int oidx5 = idx16 + idx6;

        out[oidx1 - 1] = i1i + cr2 + cr3;
        out[oidx1] = i1r + ci2 + ci3;
        out[oidx3 - 1] = tr2 + tr5;
        out[oidx2 - 1] = tr2 - tr5;
        out[oidx3] = ti2 + ti5;
        out[oidx2] = ti5 - ti2;
        out[oidx5 - 1] = tr3 + tr4;
        out[oidx4 - 1] = tr3 - tr4;
        out[oidx5] = ti3 + ti4;
        out[oidx4] = ti4 - ti3;
      }
    }
  }

  void radfg(
      final int ido,
      final int ip,
      final int l1,
      final int idl1,
      final List<double> by,
      final int in_off,
      final List<double> out,
      final int out_off,
      final int offset) {
    int idij, ipph, j2, ic, jc, lc, b, nbd;
    double dc2, ai1, ai2, ar1, ar2, ds2, dcp, arg, dsp, ar1h, ar2h, w1r, w1i;
    int iw1 = offset;

    arg = twoPi / ip.toDouble();
    dcp = math.cos(arg);
    dsp = math.sin(arg);
    ipph = (ip + 1) ~/ 2;
    nbd = (ido - 1) ~/ 2;
    if (ido != 1) {
      for (int ik = 0; ik < idl1; ik++) out[out_off + ik] = by[in_off + ik];
      for (int j = 1; j < ip; j++) {
        int idx1 = j * l1 * ido;
        for (int k = 0; k < l1; k++) {
          int idx2 = k * ido + idx1;
          out[out_off + idx2] = by[in_off + idx2];
        }
      }
      if (nbd <= l1) {
        b = -ido;
        for (int j = 1; j < ip; j++) {
          b += ido;
          idij = b - 1;
          int idx1 = j * l1 * ido;
          for (int i = 2; i < ido; i += 2) {
            idij += 2;
            int idx2 = idij + iw1;
            int idx4 = in_off + i;
            int idx5 = out_off + i;
            w1r = wtableR[idx2 - 1];
            w1i = wtableR[idx2];
            for (int k = 0; k < l1; k++) {
              int idx3 = k * ido + idx1;
              int oidx1 = idx5 + idx3;
              int iidx1 = idx4 + idx3;
              double i1i = by[iidx1 - 1];
              double i1r = by[iidx1];

              out[oidx1 - 1] = w1r * i1i + w1i * i1r;
              out[oidx1] = w1r * i1r - w1i * i1i;
            }
          }
        }
      } else {
        b = -ido;
        for (int j = 1; j < ip; j++) {
          b += ido;
          int idx1 = j * l1 * ido;
          for (int k = 0; k < l1; k++) {
            idij = b - 1;
            int idx3 = k * ido + idx1;
            for (int i = 2; i < ido; i += 2) {
              idij += 2;
              int idx2 = idij + iw1;
              w1r = wtableR[idx2 - 1];
              w1i = wtableR[idx2];
              int oidx1 = out_off + i + idx3;
              int iidx1 = in_off + i + idx3;
              double i1i = by[iidx1 - 1];
              double i1r = by[iidx1];

              out[oidx1 - 1] = w1r * i1i + w1i * i1r;
              out[oidx1] = w1r * i1r - w1i * i1i;
            }
          }
        }
      }
      if (nbd >= l1) {
        for (int j = 1; j < ipph; j++) {
          jc = ip - j;
          int idx1 = j * l1 * ido;
          int idx2 = jc * l1 * ido;
          for (int k = 0; k < l1; k++) {
            int idx3 = k * ido + idx1;
            int idx4 = k * ido + idx2;
            for (int i = 2; i < ido; i += 2) {
              int idx5 = in_off + i;
              int idx6 = out_off + i;
              int iidx1 = idx5 + idx3;
              int iidx2 = idx5 + idx4;
              int oidx1 = idx6 + idx3;
              int oidx2 = idx6 + idx4;
              double o1i = out[oidx1 - 1];
              double o1r = out[oidx1];
              double o2i = out[oidx2 - 1];
              double o2r = out[oidx2];

              by[iidx1 - 1] = o1i + o2i;
              by[iidx1] = o1r + o2r;

              by[iidx2 - 1] = o1r - o2r;
              by[iidx2] = o2i - o1i;
            }
          }
        }
      } else {
        for (int j = 1; j < ipph; j++) {
          jc = ip - j;
          int idx1 = j * l1 * ido;
          int idx2 = jc * l1 * ido;
          for (int i = 2; i < ido; i += 2) {
            int idx5 = in_off + i;
            int idx6 = out_off + i;
            for (int k = 0; k < l1; k++) {
              int idx3 = k * ido + idx1;
              int idx4 = k * ido + idx2;
              int iidx1 = idx5 + idx3;
              int iidx2 = idx5 + idx4;
              int oidx1 = idx6 + idx3;
              int oidx2 = idx6 + idx4;
              double o1i = out[oidx1 - 1];
              double o1r = out[oidx1];
              double o2i = out[oidx2 - 1];
              double o2r = out[oidx2];

              by[iidx1 - 1] = o1i + o2i;
              by[iidx1] = o1r + o2r;
              by[iidx2 - 1] = o1r - o2r;
              by[iidx2] = o2i - o1i;
            }
          }
        }
      }
    }
    for (int j = 1; j < ipph; j++) {
      jc = ip - j;
      int idx1 = j * l1 * ido;
      int idx2 = jc * l1 * ido;
      for (int k = 0; k < l1; k++) {
        int idx3 = k * ido + idx1;
        int idx4 = k * ido + idx2;
        int oidx1 = out_off + idx3;
        int oidx2 = out_off + idx4;
        double o1r = out[oidx1];
        double o2r = out[oidx2];

        by[in_off + idx3] = o1r + o2r;
        by[in_off + idx4] = o2r - o1r;
      }
    }

    ar1 = 1;
    ai1 = 0;
    int idx0 = (ip - 1) * idl1;
    for (int l = 1; l < ipph; l++) {
      lc = ip - l;
      ar1h = dcp * ar1 - dsp * ai1;
      ai1 = dcp * ai1 + dsp * ar1;
      ar1 = ar1h;
      int idx1 = l * idl1;
      int idx2 = lc * idl1;
      for (int ik = 0; ik < idl1; ik++) {
        int idx3 = out_off + ik;
        int idx4 = in_off + ik;
        out[idx3 + idx1] = by[idx4] + ar1 * by[idx4 + idl1];
        out[idx3 + idx2] = ai1 * by[idx4 + idx0];
      }
      dc2 = ar1;
      ds2 = ai1;
      ar2 = ar1;
      ai2 = ai1;
      for (int j = 2; j < ipph; j++) {
        jc = ip - j;
        ar2h = dc2 * ar2 - ds2 * ai2;
        ai2 = dc2 * ai2 + ds2 * ar2;
        ar2 = ar2h;
        int idx3 = j * idl1;
        int idx4 = jc * idl1;
        for (int ik = 0; ik < idl1; ik++) {
          int idx5 = out_off + ik;
          int idx6 = in_off + ik;
          out[idx5 + idx1] += ar2 * by[idx6 + idx3];
          out[idx5 + idx2] += ai2 * by[idx6 + idx4];
        }
      }
    }
    for (int j = 1; j < ipph; j++) {
      int idx1 = j * idl1;
      for (int ik = 0; ik < idl1; ik++) {
        out[out_off + ik] += by[in_off + ik + idx1];
      }
    }

    if (ido >= l1) {
      for (int k = 0; k < l1; k++) {
        int idx1 = k * ido;
        int idx2 = idx1 * ip;
        for (int i = 0; i < ido; i++) {
          by[in_off + i + idx2] = out[out_off + i + idx1];
        }
      }
    } else {
      for (int i = 0; i < ido; i++) {
        for (int k = 0; k < l1; k++) {
          int idx1 = k * ido;
          by[in_off + i + idx1 * ip] = out[out_off + i + idx1];
        }
      }
    }
    int idx01 = ip * ido;
    for (int j = 1; j < ipph; j++) {
      jc = ip - j;
      j2 = 2 * j;
      int idx1 = j * l1 * ido;
      int idx2 = jc * l1 * ido;
      int idx3 = j2 * ido;
      for (int k = 0; k < l1; k++) {
        int idx4 = k * ido;
        int idx5 = idx4 + idx1;
        int idx6 = idx4 + idx2;
        int idx7 = k * idx01;
        by[in_off + ido - 1 + idx3 - ido + idx7] = out[out_off + idx5];
        by[in_off + idx3 + idx7] = out[out_off + idx6];
      }
    }
    if (ido == 1) return;
    if (nbd >= l1) {
      for (int j = 1; j < ipph; j++) {
        jc = ip - j;
        j2 = 2 * j;
        int idx1 = j * l1 * ido;
        int idx2 = jc * l1 * ido;
        int idx3 = j2 * ido;
        for (int k = 0; k < l1; k++) {
          int idx4 = k * idx01;
          int idx5 = k * ido;
          for (int i = 2; i < ido; i += 2) {
            ic = ido - i;
            int idx6 = in_off + i;
            int idx7 = in_off + ic;
            int idx8 = out_off + i;
            int iidx1 = idx6 + idx3 + idx4;
            int iidx2 = idx7 + idx3 - ido + idx4;
            int oidx1 = idx8 + idx5 + idx1;
            int oidx2 = idx8 + idx5 + idx2;
            double o1i = out[oidx1 - 1];
            double o1r = out[oidx1];
            double o2i = out[oidx2 - 1];
            double o2r = out[oidx2];

            by[iidx1 - 1] = o1i + o2i;
            by[iidx2 - 1] = o1i - o2i;
            by[iidx1] = o1r + o2r;
            by[iidx2] = o2r - o1r;
          }
        }
      }
    } else {
      for (int j = 1; j < ipph; j++) {
        jc = ip - j;
        j2 = 2 * j;
        int idx1 = j * l1 * ido;
        int idx2 = jc * l1 * ido;
        int idx3 = j2 * ido;
        for (int i = 2; i < ido; i += 2) {
          ic = ido - i;
          int idx6 = in_off + i;
          int idx7 = in_off + ic;
          int idx8 = out_off + i;
          for (int k = 0; k < l1; k++) {
            int idx4 = k * idx01;
            int idx5 = k * ido;
            int iidx1 = idx6 + idx3 + idx4;
            int iidx2 = idx7 + idx3 - ido + idx4;
            int oidx1 = idx8 + idx5 + idx1;
            int oidx2 = idx8 + idx5 + idx2;
            double o1i = out[oidx1 - 1];
            double o1r = out[oidx1];
            double o2i = out[oidx2 - 1];
            double o2r = out[oidx2];

            by[iidx1 - 1] = o1i + o2i;
            by[iidx2 - 1] = o1i - o2i;
            by[iidx1] = o1r + o2r;
            by[iidx2] = o2r - o1r;
          }
        }
      }
    }
  }

  void rftfsub(
      int n, List<double> a, int offa, int nc, List<double> c, int startc) {
    int k, kk, ks, m;
    double wkr, wki, xr, xi, yr, yi;
    int idx1, idx2;

    m = n >> 1;
    ks = 2 * nc ~/ m;
    kk = 0;
    for (int j = 2; j < m; j += 2) {
      k = n - j;
      kk += ks;
      wkr = 0.5 - c[startc + nc - kk];
      wki = c[startc + kk];
      idx1 = offa + j;
      idx2 = offa + k;
      xr = a[idx1] - a[idx2];
      xi = a[idx1 + 1] + a[idx2 + 1];
      yr = wkr * xr - wki * xi;
      yi = wkr * xi + wki * xr;
      a[idx1] -= yr;
      a[idx1 + 1] = yi - a[idx1 + 1];
      a[idx2] += yr;
      a[idx2 + 1] = yi - a[idx2 + 1];
    }
    a[offa + m + 1] = -a[offa + m + 1];
  }

  void cftx020(List<double> a, int offa) {
    double x0r, x0i;
    x0r = a[offa] - a[offa + 2];
    x0i = -a[offa + 1] + a[offa + 3];
    a[offa] += a[offa + 2];
    a[offa + 1] += a[offa + 3];
    a[offa + 2] = x0r;
    a[offa + 3] = x0i;
  }

  void cftbsub(
      int n, List<double> a, int offa, List<int> ip, int nw, List<double> w) {
    if (n > 8) {
      if (n > 32) {
        cftb1st(n, a, offa, w, nw - (n >> 2));
        if ((concurrency.getNumberOfThreads() > 1) &&
            (n > concurrency.getThreadsBeginN1DFFT2Threads())) {
          cftrec4th(n, a, offa, nw, w);
        } else if (n > 512) {
          cftrec4(n, a, offa, nw, w);
        } else if (n > 128) {
          cftleaf(n, 1, a, offa, nw, w);
        } else {
          cftfx41(n, a, offa, nw, w);
        }
        bitrv2conj(n, ip, a, offa);
      } else if (n == 32) {
        cftf161(a, offa, w, nw - 8);
        bitrv216neg(a, offa);
      } else {
        cftf081(a, offa, w, 0);
        bitrv208neg(a, offa);
      }
    } else if (n == 8) {
      cftb040(a, offa);
    } else if (n == 4) {
      cftxb020(a, offa);
    }
  }

  cftfsub(
      int n, List<double> a, int offa, List<int> ip, int nw, List<double> w) {
    if (n > 8) {
      if (n < 32) {
        cftf1st(n, a, offa, w, nw - (n >> 2));

        if ((concurrency.getNumberOfThreads() > 1) &&
            (n > concurrency.getThreadsBeginN1DFFT2Threads())) {
          cftrec4th(n, a, offa, nw, w);
        } else if (n > 512) {
          cftrec4(n, a, offa, nw, w);
        } else if (n > 128) {
          cftleaf(n, 1, a, offa, nw, w);
        } else {
          cftfx41(n, a, offa, nw, w);
        }
        bitrv2(n, ip, a, offa);
      } else if (n == 32) {
        cftf161(a, offa, w, nw - 8);
        bitrv216(a, offa);
      } else {
        cftf081(a, offa, w, 0);
        bitrv208(a, offa);
      }
    } else if (n == 8) {
      cftf040(a, offa);
    } else if (n == 4) {
      cftxb020(a, offa);
    }
  }

  void cftb1st(int n, List<double> a, int offa, List<double> w, int startw) {
    // for (int i = 0; i < a.length; i++) {
    //   a[i] = 0;
    // }

    int j0, j1, j2, j3, k, m, mh;
    double wn4r, csc1, csc3, wk1r, wk1i, wk3r, wk3i, wd1r, wd1i, wd3r, wd3i;
    double x0r,
        x0i,
        x1r,
        x1i,
        x2r,
        x2i,
        x3r,
        x3i,
        y0r,
        y0i,
        y1r,
        y1i,
        y2r,
        y2i,
        y3r,
        y3i;
    int idx0, idx1, idx2, idx3, idx4, idx5;
    mh = n >> 3;
    m = 2 * mh;
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;

    x0r = a[offa] + a[idx2];
    x0i = -a[offa + 1] - a[idx2 + 1];
    x1r = a[offa] - a[idx2];
    x1i = -a[offa + 1] + a[idx2 + 1];
    x2r = a[idx1] + a[idx3];
    x2i = a[idx1 + 1] + a[idx3 + 1];
    x3r = a[idx1] - a[idx3];
    x3i = a[idx1 + 1] - a[idx3 + 1];
    a[offa] = x0r + x2r;
    a[offa + 1] = x0i - x2i;
    a[idx1] = x0r - x2r;
    a[idx1 + 1] = x0i + x2i;
    a[idx2] = x1r + x3i;
    a[idx2 + 1] = x1i + x3r;
    a[idx3] = x1r - x3i;
    a[idx3 + 1] = x1i - x3r;
    wn4r = w[startw + 1];
    csc1 = w[startw + 2];
    csc3 = w[startw + 3];
    wd1r = 1;
    wd1i = 0;
    wd3r = 1;
    wd3i = 0;
    k = 0;
    for (int j = 2; j < mh - 2; j += 4) {
      k += 4;
      idx4 = startw + k;
      wk1r = csc1 * (wd1r + w[idx4]);
      wk1i = csc1 * (wd1i + w[idx4 + 1]);
      wk3r = csc3 * (wd3r + w[idx4 + 2]);
      wk3i = csc3 * (wd3i + w[idx4 + 3]);
      wd1r = w[idx4];
      wd1i = w[idx4 + 1];
      wd3r = w[idx4 + 2];
      wd3i = w[idx4 + 3];
      j1 = j + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      idx5 = offa + j;
      x0r = a[idx5] + a[idx2];
      x0i = -a[idx5 + 1] - a[idx2 + 1];
      x1r = a[idx5] - a[offa + j2];
      x1i = -a[idx5 + 1] + a[idx2 + 1];
      y0r = a[idx5 + 2] + a[idx2 + 2];
      y0i = -a[idx5 + 3] - a[idx2 + 3];
      y1r = a[idx5 + 2] - a[idx2 + 2];
      y1i = -a[idx5 + 3] + a[idx2 + 3];
      x2r = a[idx1] + a[idx3];
      x2i = a[idx1 + 1] + a[idx3 + 1];
      x3r = a[idx1] - a[idx3];
      x3i = a[idx1 + 1] - a[idx3 + 1];
      y2r = a[idx1 + 2] + a[idx3 + 2];
      y2i = a[idx1 + 3] + a[idx3 + 3];
      y3r = a[idx1 + 2] - a[idx3 + 2];
      y3i = a[idx1 + 3] - a[idx3 + 3];
      a[idx5] = x0r + x2r;
      a[idx5 + 1] = x0i - x2i;
      a[idx5 + 2] = y0r + y2r;
      a[idx5 + 3] = y0i - y2i;
      a[idx1] = x0r - x2r;
      a[idx1 + 1] = x0i + x2i;
      a[idx1 + 2] = y0r - y2r;
      a[idx1 + 3] = y0i + y2i;
      x0r = x1r + x3i;
      x0i = x1i + x3r;
      a[idx2] = wk1r * x0r - wk1i * x0i;
      a[idx2 + 1] = wk1r * x0i + wk1i * x0r;
      x0r = y1r + y3i;
      x0i = y1i + y3r;
      a[idx2 + 2] = wd1r * x0r - wd1i * x0i;
      a[idx2 + 3] = wd1r * x0i + wd1i * x0r;
      x0r = x1r - x3i;
      x0i = x1i - x3r;
      a[idx3] = wk3r * x0r + wk3i * x0i;
      a[idx3 + 1] = wk3r * x0i - wk3i * x0r;
      x0r = y1r - y3i;
      x0i = y1i - y3r;
      a[idx3 + 2] = wd3r * x0r + wd3i * x0i;
      a[idx3 + 3] = wd3r * x0i - wd3i * x0r;
      j0 = m - j;
      j1 = j0 + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx0 = offa + j0;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      x0r = a[idx0] + a[idx2];
      x0i = -a[idx0 + 1] - a[idx2 + 1];
      x1r = a[idx0] - a[idx2];
      x1i = -a[idx0 + 1] + a[idx2 + 1];
      y0r = a[idx0 - 2] + a[idx2 - 2];
      y0i = -a[idx0 - 1] - a[idx2 - 1];
      y1r = a[idx0 - 2] - a[idx2 - 2];
      y1i = -a[idx0 - 1] + a[idx2 - 1];
      x2r = a[idx1] + a[idx3];
      x2i = a[idx1 + 1] + a[idx3 + 1];
      x3r = a[idx1] - a[idx3];
      x3i = a[idx1 + 1] - a[idx3 + 1];
      y2r = a[idx1 - 2] + a[idx3 - 2];
      y2i = a[idx1 - 1] + a[idx3 - 1];
      y3r = a[idx1 - 2] - a[idx3 - 2];
      y3i = a[idx1 - 1] - a[idx3 - 1];
      a[idx0] = x0r + x2r;
      a[idx0 + 1] = x0i - x2i;
      a[idx0 - 2] = y0r + y2r;
      a[idx0 - 1] = y0i - y2i;
      a[idx1] = x0r - x2r;
      a[idx1 + 1] = x0i + x2i;
      a[idx1 - 2] = y0r - y2r;
      a[idx1 - 1] = y0i + y2i;
      x0r = x1r + x3i;
      x0i = x1i + x3r;
      a[idx2] = wk1i * x0r - wk1r * x0i;
      a[idx2 + 1] = wk1i * x0i + wk1r * x0r;
      x0r = y1r + y3i;
      x0i = y1i + y3r;
      a[idx2 - 2] = wd1i * x0r - wd1r * x0i;
      a[idx2 - 1] = wd1i * x0i + wd1r * x0r;
      x0r = x1r - x3i;
      x0i = x1i - x3r;
      a[idx3] = wk3i * x0r + wk3r * x0i;
      a[idx3 + 1] = wk3i * x0i - wk3r * x0r;
      x0r = y1r - y3i;
      x0i = y1i - y3r;
      a[idx3 - 2] = wd3i * x0r + wd3r * x0i;
      a[idx3 - 1] = wd3i * x0i - wd3r * x0r;
    }
    wk1r = csc1 * (wd1r + wn4r);
    wk1i = csc1 * (wd1i + wn4r);
    wk3r = csc3 * (wd3r - wn4r);
    wk3i = csc3 * (wd3i - wn4r);
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx0 = offa + j0;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;
    x0r = a[idx0 - 2] + a[idx2 - 2];
    x0i = -a[idx0 - 1] - a[idx2 - 1];
    x1r = a[idx0 - 2] - a[idx2 - 2];
    x1i = -a[idx0 - 1] + a[idx2 - 1];
    x2r = a[idx1 - 2] + a[idx3 - 2];
    x2i = a[idx1 - 1] + a[idx3 - 1];
    x3r = a[idx1 - 2] - a[idx3 - 2];
    x3i = a[idx1 - 1] - a[idx3 - 1];
    a[idx0 - 2] = x0r + x2r;
    a[idx0 - 1] = x0i - x2i;
    a[idx1 - 2] = x0r - x2r;
    a[idx1 - 1] = x0i + x2i;
    x0r = x1r + x3i;
    x0i = x1i + x3r;
    a[idx2 - 2] = wk1r * x0r - wk1i * x0i;
    a[idx2 - 1] = wk1r * x0i + wk1i * x0r;
    x0r = x1r - x3i;
    x0i = x1i - x3r;
    a[idx3 - 2] = wk3r * x0r + wk3i * x0i;
    a[idx3 - 1] = wk3r * x0i - wk3i * x0r;
    x0r = a[idx0] + a[idx2];
    x0i = -a[idx0 + 1] - a[idx2 + 1];
    x1r = a[idx0] - a[idx2];
    x1i = -a[idx0 + 1] + a[idx2 + 1];
    x2r = a[idx1] + a[idx3];
    x2i = a[idx1 + 1] + a[idx3 + 1];
    x3r = a[idx1] - a[idx3];
    x3i = a[idx1 + 1] - a[idx3 + 1];
    a[idx0] = x0r + x2r;
    a[idx0 + 1] = x0i - x2i;
    a[idx1] = x0r - x2r;
    a[idx1 + 1] = x0i + x2i;
    x0r = x1r + x3i;
    x0i = x1i + x3r;
    a[idx2] = wn4r * (x0r - x0i);
    a[idx2 + 1] = wn4r * (x0i + x0r);
    x0r = x1r - x3i;
    x0i = x1i - x3r;
    a[idx3] = -wn4r * (x0r + x0i);
    a[idx3 + 1] = -wn4r * (x0i - x0r);
    x0r = a[idx0 + 2] + a[idx2 + 2];
    x0i = -a[idx0 + 3] - a[idx2 + 3];
    x1r = a[idx0 + 2] - a[idx2 + 2];
    x1i = -a[idx0 + 3] + a[idx2 + 3];
    x2r = a[idx1 + 2] + a[idx3 + 2];
    x2i = a[idx1 + 3] + a[idx3 + 3];
    x3r = a[idx1 + 2] - a[idx3 + 2];
    x3i = a[idx1 + 3] - a[idx3 + 3];
    a[idx0 + 2] = x0r + x2r;
    a[idx0 + 3] = x0i - x2i;
    a[idx1 + 2] = x0r - x2r;
    a[idx1 + 3] = x0i + x2i;
    x0r = x1r + x3i;
    x0i = x1i + x3r;
    a[idx2 + 2] = wk1i * x0r - wk1r * x0i;
    a[idx2 + 3] = wk1i * x0i + wk1r * x0r;
    x0r = x1r - x3i;
    x0i = x1i - x3r;
    a[idx3 + 2] = wk3i * x0r + wk3r * x0i;
    a[idx3 + 3] = wk3i * x0i - wk3r * x0r;
  }

  void cftrec4th(final int n, final List<double> a, final int offa,
      final int nw, final List<double> w) {
    int i;
    int idiv4, m, nthreads;
    idiv4 = 0;
    m = n >> 1;
    if (n > concurrency.getThreadsBeginN1DFFT4Threads()) {
      nthreads = 4;
      idiv4 = 1;
      m >>= 1;
    }
    final int mf = m;
    for (i = 0; i < nthreads; i++) {
      final int firstIdx = offa + i * m;
      if (i != idiv4) {
        int isplt, j, k, m;
        int idx1 = firstIdx + mf;
        m = n;
        while (m > 512) {
          m >>= 2;
          cftmdl1(m, a, idx1 - m, w, nw - (m >> 1));
        }
        cftleaf(m, 1, a, idx1 - m, nw, w);
        k = 0;
        int idx2 = firstIdx - m;
        for (j = mf - m; j > 0; j -= m) {
          k++;
          isplt = cfttree(m, j, k, a, firstIdx, nw, w);
          cftleaf(m, isplt, a, idx2 + j, nw, w);
        }
      } else {
        int isplt, j, k, m;
        int idx1 = firstIdx + mf;
        k = 1;
        m = n;
        while (m > 512) {
          m >>= 2;
          k <<= 2;
          cftmdl2(m, a, idx1 - m, w, nw - m);
        }
        cftleaf(m, 0, a, idx1 - m, nw, w);
        k >>= 1;
        int idx2 = firstIdx - m;
        for (j = mf - m; j > 0; j -= m) {
          k++;
          isplt = cfttree(m, j, k, a, firstIdx, nw, w);
          cftleaf(m, isplt, a, idx2 + j, nw, w);
        }
      }
    }
  }

  void cftrec4(int n, List<double> a, int offa, int nw, List<double> w) {
    int isplt, j, k, m;

    m = n;
    int idx1 = offa + n;
    while (m > 512) {
      m >>= 2;
      cftmdl1(m, a, idx1 - m, w, nw - (m >> 1));
    }
    cftleaf(m, 1, a, idx1 - m, nw, w);
    k = 0;
    int idx2 = offa - m;
    for (j = n - m; j > 0; j -= m) {
      k++;
      isplt = cfttree(m, j, k, a, offa, nw, w);
      cftleaf(m, isplt, a, idx2 + j, nw, w);
    }
  }

  void cftleaf(
      int n, int isplt, List<double> a, int offa, int nw, List<double> w) {
    if (n == 512) {
      cftmdl1(128, a, offa, w, nw - 64);
      cftf161(a, offa, w, nw - 8);
      cftf162(a, offa + 32, w, nw - 32);
      cftf161(a, offa + 64, w, nw - 8);
      cftf161(a, offa + 96, w, nw - 8);
      cftmdl2(128, a, offa + 128, w, nw - 128);
      cftf161(a, offa + 128, w, nw - 8);
      cftf162(a, offa + 160, w, nw - 32);
      cftf161(a, offa + 192, w, nw - 8);
      cftf162(a, offa + 224, w, nw - 32);
      cftmdl1(128, a, offa + 256, w, nw - 64);
      cftf161(a, offa + 256, w, nw - 8);
      cftf162(a, offa + 288, w, nw - 32);
      cftf161(a, offa + 320, w, nw - 8);
      cftf161(a, offa + 352, w, nw - 8);
      if (isplt != 0) {
        cftmdl1(128, a, offa + 384, w, nw - 64);
        cftf161(a, offa + 480, w, nw - 8);
      } else {
        cftmdl2(128, a, offa + 384, w, nw - 128);
        cftf162(a, offa + 480, w, nw - 32);
      }
      cftf161(a, offa + 384, w, nw - 8);
      cftf162(a, offa + 416, w, nw - 32);
      cftf161(a, offa + 448, w, nw - 8);
    } else {
      cftmdl1(64, a, offa, w, nw - 32);
      cftf081(a, offa, w, nw - 8);
      cftf082(a, offa + 16, w, nw - 8);
      cftf081(a, offa + 32, w, nw - 8);
      cftf081(a, offa + 48, w, nw - 8);
      cftmdl2(64, a, offa + 64, w, nw - 64);
      cftf081(a, offa + 64, w, nw - 8);
      cftf082(a, offa + 80, w, nw - 8);
      cftf081(a, offa + 96, w, nw - 8);
      cftf082(a, offa + 112, w, nw - 8);
      cftmdl1(64, a, offa + 128, w, nw - 32);
      cftf081(a, offa + 128, w, nw - 8);
      cftf082(a, offa + 144, w, nw - 8);
      cftf081(a, offa + 160, w, nw - 8);
      cftf081(a, offa + 176, w, nw - 8);
      if (isplt != 0) {
        cftmdl1(64, a, offa + 192, w, nw - 32);
        cftf081(a, offa + 240, w, nw - 8);
      } else {
        cftmdl2(64, a, offa + 192, w, nw - 64);
        cftf082(a, offa + 240, w, nw - 8);
      }
      cftf081(a, offa + 192, w, nw - 8);
      cftf082(a, offa + 208, w, nw - 8);
      cftf081(a, offa + 224, w, nw - 8);
    }
  }

  void cftfx41(int n, List<double> a, int offa, int nw, List<double> w) {
    if (n == 128) {
      cftf161(a, offa, w, nw - 8);
      cftf162(a, offa + 32, w, nw - 32);
      cftf161(a, offa + 64, w, nw - 8);
      cftf161(a, offa + 96, w, nw - 8);
    } else {
      cftf081(a, offa, w, nw - 8);
      cftf082(a, offa + 16, w, nw - 8);
      cftf081(a, offa + 32, w, nw - 8);
      cftf081(a, offa + 48, w, nw - 8);
    }
  }

  void bitrv2conj(int n, List<int> ip, List<double> a, int offa) {
    int j1, k1, l, m, nh, nm;
    double xr, xi, yr, yi;
    int idx0, idx1, idx2;

    m = 1;
    for (l = n >> 2; l > 8; l >>= 2) {
      m <<= 1;
    }
    nh = n >> 1;
    nm = 4 * m;
    if (l == 8) {
      for (int k = 0; k < m; k++) {
        idx0 = 4 * k;
        for (int j = 0; j < k; j++) {
          j1 = 4 * j + 2 * ip[m + k];
          k1 = idx0 + 2 * ip[m + j];
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nh;
          k1 += 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += 2;
          k1 += nh;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nh;
          k1 -= 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
        }
        k1 = idx0 + 2 * ip[m + k];
        j1 = k1 + 2;
        k1 += nh;
        idx1 = offa + j1;
        idx2 = offa + k1;
        a[idx1 - 1] = -a[idx1 - 1];
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        a[idx2 + 3] = -a[idx2 + 3];
        j1 += nm;
        k1 += 2 * nm;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 += nm;
        k1 -= nm;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 -= 2;
        k1 -= nh;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 += nh + 2;
        k1 += nh + 2;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 -= nh - nm;
        k1 += 2 * nm - 2;
        idx1 = offa + j1;
        idx2 = offa + k1;
        a[idx1 - 1] = -a[idx1 - 1];
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        a[idx2 + 3] = -a[idx2 + 3];
      }
    } else {
      for (int k = 0; k < m; k++) {
        idx0 = 4 * k;
        for (int j = 0; j < k; j++) {
          j1 = 4 * j + ip[m + k];
          k1 = idx0 + ip[m + j];
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nh;
          k1 += 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += 2;
          k1 += nh;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nh;
          k1 -= 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = -a[idx1 + 1];
          yr = a[idx2];
          yi = -a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
        }
        k1 = idx0 + ip[m + k];
        j1 = k1 + 2;
        k1 += nh;
        idx1 = offa + j1;
        idx2 = offa + k1;
        a[idx1 - 1] = -a[idx1 - 1];
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        a[idx2 + 3] = -a[idx2 + 3];
        j1 += nm;
        k1 += nm;
        idx1 = offa + j1;
        idx2 = offa + k1;
        a[idx1 - 1] = -a[idx1 - 1];
        xr = a[idx1];
        xi = -a[idx1 + 1];
        yr = a[idx2];
        yi = -a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        a[idx2 + 3] = -a[idx2 + 3];
      }
    }
  }

  void cftf161(List<double> a, int offa, List<double> w, int startw) {
    double wn4r,
        wk1r,
        wk1i,
        x0r,
        x0i,
        x1r,
        x1i,
        x2r,
        x2i,
        x3r,
        x3i,
        y0r,
        y0i,
        y1r,
        y1i,
        y2r,
        y2i,
        y3r,
        y3i,
        y4r,
        y4i,
        y5r,
        y5i,
        y6r,
        y6i,
        y7r,
        y7i,
        y8r,
        y8i,
        y9r,
        y9i,
        y10r,
        y10i,
        y11r,
        y11i,
        y12r,
        y12i,
        y13r,
        y13i,
        y14r,
        y14i,
        y15r,
        y15i;

    wn4r = w[startw + 1];
    wk1r = w[startw + 2];
    wk1i = w[startw + 3];

    x0r = a[offa] + a[offa + 16];
    x0i = a[offa + 1] + a[offa + 17];
    x1r = a[offa] - a[offa + 16];
    x1i = a[offa + 1] - a[offa + 17];
    x2r = a[offa + 8] + a[offa + 24];
    x2i = a[offa + 9] + a[offa + 25];
    x3r = a[offa + 8] - a[offa + 24];
    x3i = a[offa + 9] - a[offa + 25];
    y0r = x0r + x2r;
    y0i = x0i + x2i;
    y4r = x0r - x2r;
    y4i = x0i - x2i;
    y8r = x1r - x3i;
    y8i = x1i + x3r;
    y12r = x1r + x3i;
    y12i = x1i - x3r;
    x0r = a[offa + 2] + a[offa + 18];
    x0i = a[offa + 3] + a[offa + 19];
    x1r = a[offa + 2] - a[offa + 18];
    x1i = a[offa + 3] - a[offa + 19];
    x2r = a[offa + 10] + a[offa + 26];
    x2i = a[offa + 11] + a[offa + 27];
    x3r = a[offa + 10] - a[offa + 26];
    x3i = a[offa + 11] - a[offa + 27];
    y1r = x0r + x2r;
    y1i = x0i + x2i;
    y5r = x0r - x2r;
    y5i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    y9r = wk1r * x0r - wk1i * x0i;
    y9i = wk1r * x0i + wk1i * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    y13r = wk1i * x0r - wk1r * x0i;
    y13i = wk1i * x0i + wk1r * x0r;
    x0r = a[offa + 4] + a[offa + 20];
    x0i = a[offa + 5] + a[offa + 21];
    x1r = a[offa + 4] - a[offa + 20];
    x1i = a[offa + 5] - a[offa + 21];
    x2r = a[offa + 12] + a[offa + 28];
    x2i = a[offa + 13] + a[offa + 29];
    x3r = a[offa + 12] - a[offa + 28];
    x3i = a[offa + 13] - a[offa + 29];
    y2r = x0r + x2r;
    y2i = x0i + x2i;
    y6r = x0r - x2r;
    y6i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    y10r = wn4r * (x0r - x0i);
    y10i = wn4r * (x0i + x0r);
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    y14r = wn4r * (x0r + x0i);
    y14i = wn4r * (x0i - x0r);
    x0r = a[offa + 6] + a[offa + 22];
    x0i = a[offa + 7] + a[offa + 23];
    x1r = a[offa + 6] - a[offa + 22];
    x1i = a[offa + 7] - a[offa + 23];
    x2r = a[offa + 14] + a[offa + 30];
    x2i = a[offa + 15] + a[offa + 31];
    x3r = a[offa + 14] - a[offa + 30];
    x3i = a[offa + 15] - a[offa + 31];
    y3r = x0r + x2r;
    y3i = x0i + x2i;
    y7r = x0r - x2r;
    y7i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    y11r = wk1i * x0r - wk1r * x0i;
    y11i = wk1i * x0i + wk1r * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    y15r = wk1r * x0r - wk1i * x0i;
    y15i = wk1r * x0i + wk1i * x0r;
    x0r = y12r - y14r;
    x0i = y12i - y14i;
    x1r = y12r + y14r;
    x1i = y12i + y14i;
    x2r = y13r - y15r;
    x2i = y13i - y15i;
    x3r = y13r + y15r;
    x3i = y13i + y15i;
    a[offa + 24] = x0r + x2r;
    a[offa + 25] = x0i + x2i;
    a[offa + 26] = x0r - x2r;
    a[offa + 27] = x0i - x2i;
    a[offa + 28] = x1r - x3i;
    a[offa + 29] = x1i + x3r;
    a[offa + 30] = x1r + x3i;
    a[offa + 31] = x1i - x3r;
    x0r = y8r + y10r;
    x0i = y8i + y10i;
    x1r = y8r - y10r;
    x1i = y8i - y10i;
    x2r = y9r + y11r;
    x2i = y9i + y11i;
    x3r = y9r - y11r;
    x3i = y9i - y11i;
    a[offa + 16] = x0r + x2r;
    a[offa + 17] = x0i + x2i;
    a[offa + 18] = x0r - x2r;
    a[offa + 19] = x0i - x2i;
    a[offa + 20] = x1r - x3i;
    a[offa + 21] = x1i + x3r;
    a[offa + 22] = x1r + x3i;
    a[offa + 23] = x1i - x3r;
    x0r = y5r - y7i;
    x0i = y5i + y7r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    x0r = y5r + y7i;
    x0i = y5i - y7r;
    x3r = wn4r * (x0r - x0i);
    x3i = wn4r * (x0i + x0r);
    x0r = y4r - y6i;
    x0i = y4i + y6r;
    x1r = y4r + y6i;
    x1i = y4i - y6r;
    a[offa + 8] = x0r + x2r;
    a[offa + 9] = x0i + x2i;
    a[offa + 10] = x0r - x2r;
    a[offa + 11] = x0i - x2i;
    a[offa + 12] = x1r - x3i;
    a[offa + 13] = x1i + x3r;
    a[offa + 14] = x1r + x3i;
    a[offa + 15] = x1i - x3r;
    x0r = y0r + y2r;
    x0i = y0i + y2i;
    x1r = y0r - y2r;
    x1i = y0i - y2i;
    x2r = y1r + y3r;
    x2i = y1i + y3i;
    x3r = y1r - y3r;
    x3i = y1i - y3i;
    a[offa] = x0r + x2r;
    a[offa + 1] = x0i + x2i;
    a[offa + 2] = x0r - x2r;
    a[offa + 3] = x0i - x2i;
    a[offa + 4] = x1r - x3i;
    a[offa + 5] = x1i + x3r;
    a[offa + 6] = x1r + x3i;
    a[offa + 7] = x1i - x3r;
  }

  void bitrv216neg(List<double> a, int offa) {
    double x1r,
        x1i,
        x2r,
        x2i,
        x3r,
        x3i,
        x4r,
        x4i,
        x5r,
        x5i,
        x6r,
        x6i,
        x7r,
        x7i,
        x8r,
        x8i,
        x9r,
        x9i,
        x10r,
        x10i,
        x11r,
        x11i,
        x12r,
        x12i,
        x13r,
        x13i,
        x14r,
        x14i,
        x15r,
        x15i;

    x1r = a[offa + 2];
    x1i = a[offa + 3];
    x2r = a[offa + 4];
    x2i = a[offa + 5];
    x3r = a[offa + 6];
    x3i = a[offa + 7];
    x4r = a[offa + 8];
    x4i = a[offa + 9];
    x5r = a[offa + 10];
    x5i = a[offa + 11];
    x6r = a[offa + 12];
    x6i = a[offa + 13];
    x7r = a[offa + 14];
    x7i = a[offa + 15];
    x8r = a[offa + 16];
    x8i = a[offa + 17];
    x9r = a[offa + 18];
    x9i = a[offa + 19];
    x10r = a[offa + 20];
    x10i = a[offa + 21];
    x11r = a[offa + 22];
    x11i = a[offa + 23];
    x12r = a[offa + 24];
    x12i = a[offa + 25];
    x13r = a[offa + 26];
    x13i = a[offa + 27];
    x14r = a[offa + 28];
    x14i = a[offa + 29];
    x15r = a[offa + 30];
    x15i = a[offa + 31];
    a[offa + 2] = x15r;
    a[offa + 3] = x15i;
    a[offa + 4] = x7r;
    a[offa + 5] = x7i;
    a[offa + 6] = x11r;
    a[offa + 7] = x11i;
    a[offa + 8] = x3r;
    a[offa + 9] = x3i;
    a[offa + 10] = x13r;
    a[offa + 11] = x13i;
    a[offa + 12] = x5r;
    a[offa + 13] = x5i;
    a[offa + 14] = x9r;
    a[offa + 15] = x9i;
    a[offa + 16] = x1r;
    a[offa + 17] = x1i;
    a[offa + 18] = x14r;
    a[offa + 19] = x14i;
    a[offa + 20] = x6r;
    a[offa + 21] = x6i;
    a[offa + 22] = x10r;
    a[offa + 23] = x10i;
    a[offa + 24] = x2r;
    a[offa + 25] = x2i;
    a[offa + 26] = x12r;
    a[offa + 27] = x12i;
    a[offa + 28] = x4r;
    a[offa + 29] = x4i;
    a[offa + 30] = x8r;
    a[offa + 31] = x8i;
  }

  void cftf081(List<double> a, int offa, List<double> w, int startw) {
    double wn4r,
        x0r,
        x0i,
        x1r,
        x1i,
        x2r,
        x2i,
        x3r,
        x3i,
        y0r,
        y0i,
        y1r,
        y1i,
        y2r,
        y2i,
        y3r,
        y3i,
        y4r,
        y4i,
        y5r,
        y5i,
        y6r,
        y6i,
        y7r,
        y7i;

    wn4r = w[startw + 1];
    x0r = a[offa] + a[offa + 8];
    x0i = a[offa + 1] + a[offa + 9];
    x1r = a[offa] - a[offa + 8];
    x1i = a[offa + 1] - a[offa + 9];
    x2r = a[offa + 4] + a[offa + 12];
    x2i = a[offa + 5] + a[offa + 13];
    x3r = a[offa + 4] - a[offa + 12];
    x3i = a[offa + 5] - a[offa + 13];
    y0r = x0r + x2r;
    y0i = x0i + x2i;
    y2r = x0r - x2r;
    y2i = x0i - x2i;
    y1r = x1r - x3i;
    y1i = x1i + x3r;
    y3r = x1r + x3i;
    y3i = x1i - x3r;
    x0r = a[offa + 2] + a[offa + 10];
    x0i = a[offa + 3] + a[offa + 11];
    x1r = a[offa + 2] - a[offa + 10];
    x1i = a[offa + 3] - a[offa + 11];
    x2r = a[offa + 6] + a[offa + 14];
    x2i = a[offa + 7] + a[offa + 15];
    x3r = a[offa + 6] - a[offa + 14];
    x3i = a[offa + 7] - a[offa + 15];
    y4r = x0r + x2r;
    y4i = x0i + x2i;
    y6r = x0r - x2r;
    y6i = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    x2r = x1r + x3i;
    x2i = x1i - x3r;
    y5r = wn4r * (x0r - x0i);
    y5i = wn4r * (x0r + x0i);
    y7r = wn4r * (x2r - x2i);
    y7i = wn4r * (x2r + x2i);
    a[offa + 8] = y1r + y5r;
    a[offa + 9] = y1i + y5i;
    a[offa + 10] = y1r - y5r;
    a[offa + 11] = y1i - y5i;
    a[offa + 12] = y3r - y7i;
    a[offa + 13] = y3i + y7r;
    a[offa + 14] = y3r + y7i;
    a[offa + 15] = y3i - y7r;
    a[offa] = y0r + y4r;
    a[offa + 1] = y0i + y4i;
    a[offa + 2] = y0r - y4r;
    a[offa + 3] = y0i - y4i;
    a[offa + 4] = y2r - y6i;
    a[offa + 5] = y2i + y6r;
    a[offa + 6] = y2r + y6i;
    a[offa + 7] = y2i - y6r;
  }

  void bitrv208neg(List<double> a, int offa) {
    double x1r, x1i, x2r, x2i, x3r, x3i, x4r, x4i, x5r, x5i, x6r, x6i, x7r, x7i;

    x1r = a[offa + 2];
    x1i = a[offa + 3];
    x2r = a[offa + 4];
    x2i = a[offa + 5];
    x3r = a[offa + 6];
    x3i = a[offa + 7];
    x4r = a[offa + 8];
    x4i = a[offa + 9];
    x5r = a[offa + 10];
    x5i = a[offa + 11];
    x6r = a[offa + 12];
    x6i = a[offa + 13];
    x7r = a[offa + 14];
    x7i = a[offa + 15];
    a[offa + 2] = x7r;
    a[offa + 3] = x7i;
    a[offa + 4] = x3r;
    a[offa + 5] = x3i;
    a[offa + 6] = x5r;
    a[offa + 7] = x5i;
    a[offa + 8] = x1r;
    a[offa + 9] = x1i;
    a[offa + 10] = x6r;
    a[offa + 11] = x6i;
    a[offa + 12] = x2r;
    a[offa + 13] = x2i;
    a[offa + 14] = x4r;
    a[offa + 15] = x4i;
  }

  void cftb040(List<double> a, int offa) {
    double x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i;

    x0r = a[offa] + a[offa + 4];
    x0i = a[offa + 1] + a[offa + 5];
    x1r = a[offa] - a[offa + 4];
    x1i = a[offa + 1] - a[offa + 5];
    x2r = a[offa + 2] + a[offa + 6];
    x2i = a[offa + 3] + a[offa + 7];
    x3r = a[offa + 2] - a[offa + 6];
    x3i = a[offa + 3] - a[offa + 7];
    a[offa] = x0r + x2r;
    a[offa + 1] = x0i + x2i;
    a[offa + 2] = x1r + x3i;
    a[offa + 3] = x1i - x3r;
    a[offa + 4] = x0r - x2r;
    a[offa + 5] = x0i - x2i;
    a[offa + 6] = x1r - x3i;
    a[offa + 7] = x1i + x3r;
  }

  void cftxb020(List<double> a, int offa) {
    double x0r, x0i;

    x0r = a[offa] - a[offa + 2];
    x0i = a[offa + 1] - a[offa + 3];
    a[offa] += a[offa + 2];
    a[offa + 1] += a[offa + 3];
    a[offa + 2] = x0r;
    a[offa + 3] = x0i;
  }

  void cftf1st(int n, List<double> a, int offa, List<double> w, int startw) {
    int j0, j1, j2, j3, k, m, mh;
    double wn4r, csc1, csc3, wk1r, wk1i, wk3r, wk3i, wd1r, wd1i, wd3r, wd3i;
    double x0r,
        x0i,
        x1r,
        x1i,
        x2r,
        x2i,
        x3r,
        x3i,
        y0r,
        y0i,
        y1r,
        y1i,
        y2r,
        y2i,
        y3r,
        y3i;
    int idx0, idx1, idx2, idx3, idx4, idx5;
    mh = n >> 3;
    m = 2 * mh;
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;
    x0r = a[offa] + a[idx2];
    x0i = a[offa + 1] + a[idx2 + 1];
    x1r = a[offa] - a[idx2];
    x1i = a[offa + 1] - a[idx2 + 1];
    x2r = a[idx1] + a[idx3];
    x2i = a[idx1 + 1] + a[idx3 + 1];
    x3r = a[idx1] - a[idx3];
    x3i = a[idx1 + 1] - a[idx3 + 1];
    a[offa] = x0r + x2r;
    a[offa + 1] = x0i + x2i;
    a[idx1] = x0r - x2r;
    a[idx1 + 1] = x0i - x2i;
    a[idx2] = x1r - x3i;
    a[idx2 + 1] = x1i + x3r;
    a[idx3] = x1r + x3i;
    a[idx3 + 1] = x1i - x3r;
    wn4r = w[startw + 1];
    csc1 = w[startw + 2];
    csc3 = w[startw + 3];
    wd1r = 1;
    wd1i = 0;
    wd3r = 1;
    wd3i = 0;
    k = 0;
    for (int j = 2; j < mh - 2; j += 4) {
      k += 4;
      idx4 = startw + k;
      wk1r = csc1 * (wd1r + w[idx4]);
      wk1i = csc1 * (wd1i + w[idx4 + 1]);
      wk3r = csc3 * (wd3r + w[idx4 + 2]);
      wk3i = csc3 * (wd3i + w[idx4 + 3]);
      wd1r = w[idx4];
      wd1i = w[idx4 + 1];
      wd3r = w[idx4 + 2];
      wd3i = w[idx4 + 3];
      j1 = j + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      idx5 = offa + j;
      x0r = a[idx5] + a[idx2];
      x0i = a[idx5 + 1] + a[idx2 + 1];
      x1r = a[idx5] - a[idx2];
      x1i = a[idx5 + 1] - a[idx2 + 1];
      y0r = a[idx5 + 2] + a[idx2 + 2];
      y0i = a[idx5 + 3] + a[idx2 + 3];
      y1r = a[idx5 + 2] - a[idx2 + 2];
      y1i = a[idx5 + 3] - a[idx2 + 3];
      x2r = a[idx1] + a[idx3];
      x2i = a[idx1 + 1] + a[idx3 + 1];
      x3r = a[idx1] - a[idx3];
      x3i = a[idx1 + 1] - a[idx3 + 1];
      y2r = a[idx1 + 2] + a[idx3 + 2];
      y2i = a[idx1 + 3] + a[idx3 + 3];
      y3r = a[idx1 + 2] - a[idx3 + 2];
      y3i = a[idx1 + 3] - a[idx3 + 3];
      a[idx5] = x0r + x2r;
      a[idx5 + 1] = x0i + x2i;
      a[idx5 + 2] = y0r + y2r;
      a[idx5 + 3] = y0i + y2i;
      a[idx1] = x0r - x2r;
      a[idx1 + 1] = x0i - x2i;
      a[idx1 + 2] = y0r - y2r;
      a[idx1 + 3] = y0i - y2i;
      x0r = x1r - x3i;
      x0i = x1i + x3r;
      a[idx2] = wk1r * x0r - wk1i * x0i;
      a[idx2 + 1] = wk1r * x0i + wk1i * x0r;
      x0r = y1r - y3i;
      x0i = y1i + y3r;
      a[idx2 + 2] = wd1r * x0r - wd1i * x0i;
      a[idx2 + 3] = wd1r * x0i + wd1i * x0r;
      x0r = x1r + x3i;
      x0i = x1i - x3r;
      a[idx3] = wk3r * x0r + wk3i * x0i;
      a[idx3 + 1] = wk3r * x0i - wk3i * x0r;
      x0r = y1r + y3i;
      x0i = y1i - y3r;
      a[idx3 + 2] = wd3r * x0r + wd3i * x0i;
      a[idx3 + 3] = wd3r * x0i - wd3i * x0r;
      j0 = m - j;
      j1 = j0 + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx0 = offa + j0;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      x0r = a[idx0] + a[idx2];
      x0i = a[idx0 + 1] + a[idx2 + 1];
      x1r = a[idx0] - a[idx2];
      x1i = a[idx0 + 1] - a[idx2 + 1];
      y0r = a[idx0 - 2] + a[idx2 - 2];
      y0i = a[idx0 - 1] + a[idx2 - 1];
      y1r = a[idx0 - 2] - a[idx2 - 2];
      y1i = a[idx0 - 1] - a[idx2 - 1];
      x2r = a[idx1] + a[idx3];
      x2i = a[idx1 + 1] + a[idx3 + 1];
      x3r = a[idx1] - a[idx3];
      x3i = a[idx1 + 1] - a[idx3 + 1];
      y2r = a[idx1 - 2] + a[idx3 - 2];
      y2i = a[idx1 - 1] + a[idx3 - 1];
      y3r = a[idx1 - 2] - a[idx3 - 2];
      y3i = a[idx1 - 1] - a[idx3 - 1];
      a[idx0] = x0r + x2r;
      a[idx0 + 1] = x0i + x2i;
      a[idx0 - 2] = y0r + y2r;
      a[idx0 - 1] = y0i + y2i;
      a[idx1] = x0r - x2r;
      a[idx1 + 1] = x0i - x2i;
      a[idx1 - 2] = y0r - y2r;
      a[idx1 - 1] = y0i - y2i;
      x0r = x1r - x3i;
      x0i = x1i + x3r;
      a[idx2] = wk1i * x0r - wk1r * x0i;
      a[idx2 + 1] = wk1i * x0i + wk1r * x0r;
      x0r = y1r - y3i;
      x0i = y1i + y3r;
      a[idx2 - 2] = wd1i * x0r - wd1r * x0i;
      a[idx2 - 1] = wd1i * x0i + wd1r * x0r;
      x0r = x1r + x3i;
      x0i = x1i - x3r;
      a[idx3] = wk3i * x0r + wk3r * x0i;
      a[idx3 + 1] = wk3i * x0i - wk3r * x0r;
      x0r = y1r + y3i;
      x0i = y1i - y3r;
      a[offa + j3 - 2] = wd3i * x0r + wd3r * x0i;
      a[offa + j3 - 1] = wd3i * x0i - wd3r * x0r;
    }
    wk1r = csc1 * (wd1r + wn4r);
    wk1i = csc1 * (wd1i + wn4r);
    wk3r = csc3 * (wd3r - wn4r);
    wk3i = csc3 * (wd3i - wn4r);
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx0 = offa + j0;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;
    x0r = a[idx0 - 2] + a[idx2 - 2];
    x0i = a[idx0 - 1] + a[idx2 - 1];
    x1r = a[idx0 - 2] - a[idx2 - 2];
    x1i = a[idx0 - 1] - a[idx2 - 1];
    x2r = a[idx1 - 2] + a[idx3 - 2];
    x2i = a[idx1 - 1] + a[idx3 - 1];
    x3r = a[idx1 - 2] - a[idx3 - 2];
    x3i = a[idx1 - 1] - a[idx3 - 1];
    a[idx0 - 2] = x0r + x2r;
    a[idx0 - 1] = x0i + x2i;
    a[idx1 - 2] = x0r - x2r;
    a[idx1 - 1] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[idx2 - 2] = wk1r * x0r - wk1i * x0i;
    a[idx2 - 1] = wk1r * x0i + wk1i * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[idx3 - 2] = wk3r * x0r + wk3i * x0i;
    a[idx3 - 1] = wk3r * x0i - wk3i * x0r;
    x0r = a[idx0] + a[idx2];
    x0i = a[idx0 + 1] + a[idx2 + 1];
    x1r = a[idx0] - a[idx2];
    x1i = a[idx0 + 1] - a[idx2 + 1];
    x2r = a[idx1] + a[idx3];
    x2i = a[idx1 + 1] + a[idx3 + 1];
    x3r = a[idx1] - a[idx3];
    x3i = a[idx1 + 1] - a[idx3 + 1];
    a[idx0] = x0r + x2r;
    a[idx0 + 1] = x0i + x2i;
    a[idx1] = x0r - x2r;
    a[idx1 + 1] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[idx2] = wn4r * (x0r - x0i);
    a[idx2 + 1] = wn4r * (x0i + x0r);
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[idx3] = -wn4r * (x0r + x0i);
    a[idx3 + 1] = -wn4r * (x0i - x0r);
    x0r = a[idx0 + 2] + a[idx2 + 2];
    x0i = a[idx0 + 3] + a[idx2 + 3];
    x1r = a[idx0 + 2] - a[idx2 + 2];
    x1i = a[idx0 + 3] - a[idx2 + 3];
    x2r = a[idx1 + 2] + a[idx3 + 2];
    x2i = a[idx1 + 3] + a[idx3 + 3];
    x3r = a[idx1 + 2] - a[idx3 + 2];
    x3i = a[idx1 + 3] - a[idx3 + 3];
    a[idx0 + 2] = x0r + x2r;
    a[idx0 + 3] = x0i + x2i;
    a[idx1 + 2] = x0r - x2r;
    a[idx1 + 3] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[idx2 + 2] = wk1i * x0r - wk1r * x0i;
    a[idx2 + 3] = wk1i * x0i + wk1r * x0r;
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[idx3 + 2] = wk3i * x0r + wk3r * x0i;
    a[idx3 + 3] = wk3i * x0i - wk3r * x0r;
  }

  void bitrv2(int n, List<int> ip, List<double> a, int offa) {
    int j1, k1, l, m, nh, nm;
    double xr, xi, yr, yi;
    int idx0, idx1, idx2;

    m = 1;
    for (l = n >> 2; l > 8; l >>= 2) {
      m <<= 1;
    }
    nh = n >> 1;
    nm = 4 * m;
    if (l == 8) {
      for (int k = 0; k < m; k++) {
        idx0 = 4 * k;
        for (int j = 0; j < k; j++) {
          j1 = 4 * j + 2 * ip[m + k];
          k1 = idx0 + 2 * ip[m + j];
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nh;
          k1 += 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += 2;
          k1 += nh;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nh;
          k1 -= 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= 2 * nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
        }
        k1 = idx0 + 2 * ip[m + k];
        j1 = k1 + 2;
        k1 += nh;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 += nm;
        k1 += 2 * nm;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 += nm;
        k1 -= nm;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 -= 2;
        k1 -= nh;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 += nh + 2;
        k1 += nh + 2;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 -= nh - nm;
        k1 += 2 * nm - 2;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
      }
    } else {
      for (int k = 0; k < m; k++) {
        idx0 = 4 * k;
        for (int j = 0; j < k; j++) {
          j1 = 4 * j + ip[m + k];
          k1 = idx0 + ip[m + j];
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nh;
          k1 += 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += 2;
          k1 += nh;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 += nm;
          k1 += nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nh;
          k1 -= 2;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
          j1 -= nm;
          k1 -= nm;
          idx1 = offa + j1;
          idx2 = offa + k1;
          xr = a[idx1];
          xi = a[idx1 + 1];
          yr = a[idx2];
          yi = a[idx2 + 1];
          a[idx1] = yr;
          a[idx1 + 1] = yi;
          a[idx2] = xr;
          a[idx2 + 1] = xi;
        }
        k1 = idx0 + ip[m + k];
        j1 = k1 + 2;
        k1 += nh;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
        j1 += nm;
        k1 += nm;
        idx1 = offa + j1;
        idx2 = offa + k1;
        xr = a[idx1];
        xi = a[idx1 + 1];
        yr = a[idx2];
        yi = a[idx2 + 1];
        a[idx1] = yr;
        a[idx1 + 1] = yi;
        a[idx2] = xr;
        a[idx2 + 1] = xi;
      }
    }
  }

  void bitrv216(List<double> a, int offa) {
    double x1r,
        x1i,
        x2r,
        x2i,
        x3r,
        x3i,
        x4r,
        x4i,
        x5r,
        x5i,
        x6r,
        x6i,
        x7r,
        x7i,
        x8r,
        x8i,
        x9r,
        x9i,
        x10r,
        x10i,
        x11r,
        x11i,
        x12r,
        x12i,
        x13r,
        x13i,
        x14r,
        x14i,
        x15r,
        x15i;

    x1r = a[offa + 2];
    x1i = a[offa + 3];
    x2r = a[offa + 4];
    x2i = a[offa + 5];
    x3r = a[offa + 6];
    x3i = a[offa + 7];
    x4r = a[offa + 8];
    x4i = a[offa + 9];
    x5r = a[offa + 10];
    x5i = a[offa + 11];
    x6r = a[offa + 12];
    x6i = a[offa + 13];
    x7r = a[offa + 14];
    x7i = a[offa + 15];
    x8r = a[offa + 16];
    x8i = a[offa + 17];
    x9r = a[offa + 18];
    x9i = a[offa + 19];
    x10r = a[offa + 20];
    x10i = a[offa + 21];
    x11r = a[offa + 22];
    x11i = a[offa + 23];
    x12r = a[offa + 24];
    x12i = a[offa + 25];
    x13r = a[offa + 26];
    x13i = a[offa + 27];
    x14r = a[offa + 28];
    x14i = a[offa + 29];
    x15r = a[offa + 30];
    x15i = a[offa + 31];
    a[offa + 2] = x15r;
    a[offa + 3] = x15i;
    a[offa + 4] = x7r;
    a[offa + 5] = x7i;
    a[offa + 6] = x11r;
    a[offa + 7] = x11i;
    a[offa + 8] = x3r;
    a[offa + 9] = x3i;
    a[offa + 10] = x13r;
    a[offa + 11] = x13i;
    a[offa + 12] = x5r;
    a[offa + 13] = x5i;
    a[offa + 14] = x9r;
    a[offa + 15] = x9i;
    a[offa + 16] = x1r;
    a[offa + 17] = x1i;
    a[offa + 18] = x14r;
    a[offa + 19] = x14i;
    a[offa + 20] = x6r;
    a[offa + 21] = x6i;
    a[offa + 22] = x10r;
    a[offa + 23] = x10i;
    a[offa + 24] = x2r;
    a[offa + 25] = x2i;
    a[offa + 26] = x12r;
    a[offa + 27] = x12i;
    a[offa + 28] = x4r;
    a[offa + 29] = x4i;
    a[offa + 30] = x8r;
    a[offa + 31] = x8i;
  }

  void bitrv208(List<double> a, int offa) {
    double x1r, x1i, x3r, x3i, x4r, x4i, x6r, x6i;

    x1r = a[offa + 2];
    x1i = a[offa + 3];
    x3r = a[offa + 6];
    x3i = a[offa + 7];
    x4r = a[offa + 8];
    x4i = a[offa + 9];
    x6r = a[offa + 12];
    x6i = a[offa + 13];
    a[offa + 2] = x4r;
    a[offa + 3] = x4i;
    a[offa + 6] = x6r;
    a[offa + 7] = x6i;
    a[offa + 8] = x1r;
    a[offa + 9] = x1i;
    a[offa + 12] = x3r;
    a[offa + 13] = x3i;
  }

  void cftf040(List<double> a, int offa) {
    double x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i;

    x0r = a[offa] + a[offa + 4];
    x0i = a[offa + 1] + a[offa + 5];
    x1r = a[offa] - a[offa + 4];
    x1i = a[offa + 1] - a[offa + 5];
    x2r = a[offa + 2] + a[offa + 6];
    x2i = a[offa + 3] + a[offa + 7];
    x3r = a[offa + 2] - a[offa + 6];
    x3i = a[offa + 3] - a[offa + 7];
    a[offa] = x0r + x2r;
    a[offa + 1] = x0i + x2i;
    a[offa + 2] = x1r - x3i;
    a[offa + 3] = x1i + x3r;
    a[offa + 4] = x0r - x2r;
    a[offa + 5] = x0i - x2i;
    a[offa + 6] = x1r + x3i;
    a[offa + 7] = x1i - x3r;
  }

  void cftmdl1(int n, List<double> a, int offa, List<double> w, int startw) {
    int j0, j1, j2, j3, k, m, mh;
    double wn4r, wk1r, wk1i, wk3r, wk3i;
    double x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i;
    int idx0, idx1, idx2, idx3, idx4, idx5;

    mh = n >> 3;
    m = 2 * mh;
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;
    x0r = a[offa] + a[idx2];
    x0i = a[offa + 1] + a[idx2 + 1];
    x1r = a[offa] - a[idx2];
    x1i = a[offa + 1] - a[idx2 + 1];
    x2r = a[idx1] + a[idx3];
    x2i = a[idx1 + 1] + a[idx3 + 1];
    x3r = a[idx1] - a[idx3];
    x3i = a[idx1 + 1] - a[idx3 + 1];
    a[offa] = x0r + x2r;
    a[offa + 1] = x0i + x2i;
    a[idx1] = x0r - x2r;
    a[idx1 + 1] = x0i - x2i;
    a[idx2] = x1r - x3i;
    a[idx2 + 1] = x1i + x3r;
    a[idx3] = x1r + x3i;
    a[idx3 + 1] = x1i - x3r;
    wn4r = w[startw + 1];
    k = 0;
    for (int j = 2; j < mh; j += 2) {
      k += 4;
      idx4 = startw + k;
      wk1r = w[idx4];
      wk1i = w[idx4 + 1];
      wk3r = w[idx4 + 2];
      wk3i = w[idx4 + 3];
      j1 = j + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      idx5 = offa + j;
      x0r = a[idx5] + a[idx2];
      x0i = a[idx5 + 1] + a[idx2 + 1];
      x1r = a[idx5] - a[idx2];
      x1i = a[idx5 + 1] - a[idx2 + 1];
      x2r = a[idx1] + a[idx3];
      x2i = a[idx1 + 1] + a[idx3 + 1];
      x3r = a[idx1] - a[idx3];
      x3i = a[idx1 + 1] - a[idx3 + 1];
      a[idx5] = x0r + x2r;
      a[idx5 + 1] = x0i + x2i;
      a[idx1] = x0r - x2r;
      a[idx1 + 1] = x0i - x2i;
      x0r = x1r - x3i;
      x0i = x1i + x3r;
      a[idx2] = wk1r * x0r - wk1i * x0i;
      a[idx2 + 1] = wk1r * x0i + wk1i * x0r;
      x0r = x1r + x3i;
      x0i = x1i - x3r;
      a[idx3] = wk3r * x0r + wk3i * x0i;
      a[idx3 + 1] = wk3r * x0i - wk3i * x0r;
      j0 = m - j;
      j1 = j0 + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx0 = offa + j0;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      x0r = a[idx0] + a[idx2];
      x0i = a[idx0 + 1] + a[idx2 + 1];
      x1r = a[idx0] - a[idx2];
      x1i = a[idx0 + 1] - a[idx2 + 1];
      x2r = a[idx1] + a[idx3];
      x2i = a[idx1 + 1] + a[idx3 + 1];
      x3r = a[idx1] - a[idx3];
      x3i = a[idx1 + 1] - a[idx3 + 1];
      a[idx0] = x0r + x2r;
      a[idx0 + 1] = x0i + x2i;
      a[idx1] = x0r - x2r;
      a[idx1 + 1] = x0i - x2i;
      x0r = x1r - x3i;
      x0i = x1i + x3r;
      a[idx2] = wk1i * x0r - wk1r * x0i;
      a[idx2 + 1] = wk1i * x0i + wk1r * x0r;
      x0r = x1r + x3i;
      x0i = x1i - x3r;
      a[idx3] = wk3i * x0r + wk3r * x0i;
      a[idx3 + 1] = wk3i * x0i - wk3r * x0r;
    }
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx0 = offa + j0;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;
    x0r = a[idx0] + a[idx2];
    x0i = a[idx0 + 1] + a[idx2 + 1];
    x1r = a[idx0] - a[idx2];
    x1i = a[idx0 + 1] - a[idx2 + 1];
    x2r = a[idx1] + a[idx3];
    x2i = a[idx1 + 1] + a[idx3 + 1];
    x3r = a[idx1] - a[idx3];
    x3i = a[idx1 + 1] - a[idx3 + 1];
    a[idx0] = x0r + x2r;
    a[idx0 + 1] = x0i + x2i;
    a[idx1] = x0r - x2r;
    a[idx1 + 1] = x0i - x2i;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[idx2] = wn4r * (x0r - x0i);
    a[idx2 + 1] = wn4r * (x0i + x0r);
    x0r = x1r + x3i;
    x0i = x1i - x3r;
    a[idx3] = -wn4r * (x0r + x0i);
    a[idx3 + 1] = -wn4r * (x0i - x0r);
  }

  cfttree(
      int n, int j, int k, List<double> a, int offa, int nw, List<double> w) {
    int i, isplt, m;
    int idx1 = offa - n;
    if ((k & 3) != 0) {
      isplt = k & 1;
      if (isplt != 0) {
        cftmdl1(n, a, idx1 + j, w, nw - (n >> 1));
      } else {
        cftmdl2(n, a, idx1 + j, w, nw - n);
      }
    } else {
      m = n;
      for (i = k; (i & 3) == 0; i >>= 2) {
        m <<= 2;
      }
      isplt = i & 1;
      int idx2 = offa + j;
      if (isplt != 0) {
        while (m > 128) {
          cftmdl1(m, a, idx2 - m, w, nw - (m >> 1));
          m >>= 2;
        }
      } else {
        while (m > 128) {
          cftmdl2(m, a, idx2 - m, w, nw - m);
          m >>= 2;
        }
      }
    }
    return isplt;
  }

  void cftmdl2(int n, List<double> a, int offa, List<double> w, int startw) {
    int j0, j1, j2, j3, k, kr, m, mh;
    double wn4r, wk1r, wk1i, wk3r, wk3i, wd1r, wd1i, wd3r, wd3i;
    double x0r, x0i, x1r, x1i, x2r, x2i, x3r, x3i, y0r, y0i, y2r, y2i;
    int idx0, idx1, idx2, idx3, idx4, idx5, idx6;

    mh = n >> 3;
    m = 2 * mh;
    wn4r = w[startw + 1];
    j1 = m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;
    x0r = a[offa] - a[idx2 + 1];
    x0i = a[offa + 1] + a[idx2];
    x1r = a[offa] + a[idx2 + 1];
    x1i = a[offa + 1] - a[idx2];
    x2r = a[idx1] - a[idx3 + 1];
    x2i = a[idx1 + 1] + a[idx3];
    x3r = a[idx1] + a[idx3 + 1];
    x3i = a[idx1 + 1] - a[idx3];
    y0r = wn4r * (x2r - x2i);
    y0i = wn4r * (x2i + x2r);
    a[offa] = x0r + y0r;
    a[offa + 1] = x0i + y0i;
    a[idx1] = x0r - y0r;
    a[idx1 + 1] = x0i - y0i;
    y0r = wn4r * (x3r - x3i);
    y0i = wn4r * (x3i + x3r);
    a[idx2] = x1r - y0i;
    a[idx2 + 1] = x1i + y0r;
    a[idx3] = x1r + y0i;
    a[idx3 + 1] = x1i - y0r;
    k = 0;
    kr = 2 * m;
    for (int j = 2; j < mh; j += 2) {
      k += 4;
      idx4 = startw + k;
      wk1r = w[idx4];
      wk1i = w[idx4 + 1];
      wk3r = w[idx4 + 2];
      wk3i = w[idx4 + 3];
      kr -= 4;
      idx5 = startw + kr;
      wd1i = w[idx5];
      wd1r = w[idx5 + 1];
      wd3i = w[idx5 + 2];
      wd3r = w[idx5 + 3];
      j1 = j + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      idx6 = offa + j;
      x0r = a[idx6] - a[idx2 + 1];
      x0i = a[idx6 + 1] + a[idx2];
      x1r = a[idx6] + a[idx2 + 1];
      x1i = a[idx6 + 1] - a[idx2];
      x2r = a[idx1] - a[idx3 + 1];
      x2i = a[idx1 + 1] + a[idx3];
      x3r = a[idx1] + a[idx3 + 1];
      x3i = a[idx1 + 1] - a[idx3];
      y0r = wk1r * x0r - wk1i * x0i;
      y0i = wk1r * x0i + wk1i * x0r;
      y2r = wd1r * x2r - wd1i * x2i;
      y2i = wd1r * x2i + wd1i * x2r;
      a[idx6] = y0r + y2r;
      a[idx6 + 1] = y0i + y2i;
      a[idx1] = y0r - y2r;
      a[idx1 + 1] = y0i - y2i;
      y0r = wk3r * x1r + wk3i * x1i;
      y0i = wk3r * x1i - wk3i * x1r;
      y2r = wd3r * x3r + wd3i * x3i;
      y2i = wd3r * x3i - wd3i * x3r;
      a[idx2] = y0r + y2r;
      a[idx2 + 1] = y0i + y2i;
      a[idx3] = y0r - y2r;
      a[idx3 + 1] = y0i - y2i;
      j0 = m - j;
      j1 = j0 + m;
      j2 = j1 + m;
      j3 = j2 + m;
      idx0 = offa + j0;
      idx1 = offa + j1;
      idx2 = offa + j2;
      idx3 = offa + j3;
      x0r = a[idx0] - a[idx2 + 1];
      x0i = a[idx0 + 1] + a[idx2];
      x1r = a[idx0] + a[idx2 + 1];
      x1i = a[idx0 + 1] - a[idx2];
      x2r = a[idx1] - a[idx3 + 1];
      x2i = a[idx1 + 1] + a[idx3];
      x3r = a[idx1] + a[idx3 + 1];
      x3i = a[idx1 + 1] - a[idx3];
      y0r = wd1i * x0r - wd1r * x0i;
      y0i = wd1i * x0i + wd1r * x0r;
      y2r = wk1i * x2r - wk1r * x2i;
      y2i = wk1i * x2i + wk1r * x2r;
      a[idx0] = y0r + y2r;
      a[idx0 + 1] = y0i + y2i;
      a[idx1] = y0r - y2r;
      a[idx1 + 1] = y0i - y2i;
      y0r = wd3i * x1r + wd3r * x1i;
      y0i = wd3i * x1i - wd3r * x1r;
      y2r = wk3i * x3r + wk3r * x3i;
      y2i = wk3i * x3i - wk3r * x3r;
      a[idx2] = y0r + y2r;
      a[idx2 + 1] = y0i + y2i;
      a[idx3] = y0r - y2r;
      a[idx3 + 1] = y0i - y2i;
    }
    wk1r = w[startw + m];
    wk1i = w[startw + m + 1];
    j0 = mh;
    j1 = j0 + m;
    j2 = j1 + m;
    j3 = j2 + m;
    idx0 = offa + j0;
    idx1 = offa + j1;
    idx2 = offa + j2;
    idx3 = offa + j3;
    x0r = a[idx0] - a[idx2 + 1];
    x0i = a[idx0 + 1] + a[idx2];
    x1r = a[idx0] + a[idx2 + 1];
    x1i = a[idx0 + 1] - a[idx2];
    x2r = a[idx1] - a[idx3 + 1];
    x2i = a[idx1 + 1] + a[idx3];
    x3r = a[idx1] + a[idx3 + 1];
    x3i = a[idx1 + 1] - a[idx3];
    y0r = wk1r * x0r - wk1i * x0i;
    y0i = wk1r * x0i + wk1i * x0r;
    y2r = wk1i * x2r - wk1r * x2i;
    y2i = wk1i * x2i + wk1r * x2r;
    a[idx0] = y0r + y2r;
    a[idx0 + 1] = y0i + y2i;
    a[idx1] = y0r - y2r;
    a[idx1 + 1] = y0i - y2i;
    y0r = wk1i * x1r - wk1r * x1i;
    y0i = wk1i * x1i + wk1r * x1r;
    y2r = wk1r * x3r - wk1i * x3i;
    y2i = wk1r * x3i + wk1i * x3r;
    a[idx2] = y0r - y2r;
    a[idx2 + 1] = y0i - y2i;
    a[idx3] = y0r + y2r;
    a[idx3 + 1] = y0i + y2i;
  }

  void cftf162(List<double> a, int offa, List<double> w, int startw) {
    double wn4r,
        wk1r,
        wk1i,
        wk2r,
        wk2i,
        wk3r,
        wk3i,
        x0r,
        x0i,
        x1r,
        x1i,
        x2r,
        x2i,
        y0r,
        y0i,
        y1r,
        y1i,
        y2r,
        y2i,
        y3r,
        y3i,
        y4r,
        y4i,
        y5r,
        y5i,
        y6r,
        y6i,
        y7r,
        y7i,
        y8r,
        y8i,
        y9r,
        y9i,
        y10r,
        y10i,
        y11r,
        y11i,
        y12r,
        y12i,
        y13r,
        y13i,
        y14r,
        y14i,
        y15r,
        y15i;

    wn4r = w[startw + 1];
    wk1r = w[startw + 4];
    wk1i = w[startw + 5];
    wk3r = w[startw + 6];
    wk3i = -w[startw + 7];
    wk2r = w[startw + 8];
    wk2i = w[startw + 9];
    x1r = a[offa] - a[offa + 17];
    x1i = a[offa + 1] + a[offa + 16];
    x0r = a[offa + 8] - a[offa + 25];
    x0i = a[offa + 9] + a[offa + 24];
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    y0r = x1r + x2r;
    y0i = x1i + x2i;
    y4r = x1r - x2r;
    y4i = x1i - x2i;
    x1r = a[offa] + a[offa + 17];
    x1i = a[offa + 1] - a[offa + 16];
    x0r = a[offa + 8] + a[offa + 25];
    x0i = a[offa + 9] - a[offa + 24];
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    y8r = x1r - x2i;
    y8i = x1i + x2r;
    y12r = x1r + x2i;
    y12i = x1i - x2r;
    x0r = a[offa + 2] - a[offa + 19];
    x0i = a[offa + 3] + a[offa + 18];
    x1r = wk1r * x0r - wk1i * x0i;
    x1i = wk1r * x0i + wk1i * x0r;
    x0r = a[offa + 10] - a[offa + 27];
    x0i = a[offa + 11] + a[offa + 26];
    x2r = wk3i * x0r - wk3r * x0i;
    x2i = wk3i * x0i + wk3r * x0r;
    y1r = x1r + x2r;
    y1i = x1i + x2i;
    y5r = x1r - x2r;
    y5i = x1i - x2i;
    x0r = a[offa + 2] + a[offa + 19];
    x0i = a[offa + 3] - a[offa + 18];
    x1r = wk3r * x0r - wk3i * x0i;
    x1i = wk3r * x0i + wk3i * x0r;
    x0r = a[offa + 10] + a[offa + 27];
    x0i = a[offa + 11] - a[offa + 26];
    x2r = wk1r * x0r + wk1i * x0i;
    x2i = wk1r * x0i - wk1i * x0r;
    y9r = x1r - x2r;
    y9i = x1i - x2i;
    y13r = x1r + x2r;
    y13i = x1i + x2i;
    x0r = a[offa + 4] - a[offa + 21];
    x0i = a[offa + 5] + a[offa + 20];
    x1r = wk2r * x0r - wk2i * x0i;
    x1i = wk2r * x0i + wk2i * x0r;
    x0r = a[offa + 12] - a[offa + 29];
    x0i = a[offa + 13] + a[offa + 28];
    x2r = wk2i * x0r - wk2r * x0i;
    x2i = wk2i * x0i + wk2r * x0r;
    y2r = x1r + x2r;
    y2i = x1i + x2i;
    y6r = x1r - x2r;
    y6i = x1i - x2i;
    x0r = a[offa + 4] + a[offa + 21];
    x0i = a[offa + 5] - a[offa + 20];
    x1r = wk2i * x0r - wk2r * x0i;
    x1i = wk2i * x0i + wk2r * x0r;
    x0r = a[offa + 12] + a[offa + 29];
    x0i = a[offa + 13] - a[offa + 28];
    x2r = wk2r * x0r - wk2i * x0i;
    x2i = wk2r * x0i + wk2i * x0r;
    y10r = x1r - x2r;
    y10i = x1i - x2i;
    y14r = x1r + x2r;
    y14i = x1i + x2i;
    x0r = a[offa + 6] - a[offa + 23];
    x0i = a[offa + 7] + a[offa + 22];
    x1r = wk3r * x0r - wk3i * x0i;
    x1i = wk3r * x0i + wk3i * x0r;
    x0r = a[offa + 14] - a[offa + 31];
    x0i = a[offa + 15] + a[offa + 30];
    x2r = wk1i * x0r - wk1r * x0i;
    x2i = wk1i * x0i + wk1r * x0r;
    y3r = x1r + x2r;
    y3i = x1i + x2i;
    y7r = x1r - x2r;
    y7i = x1i - x2i;
    x0r = a[offa + 6] + a[offa + 23];
    x0i = a[offa + 7] - a[offa + 22];
    x1r = wk1i * x0r + wk1r * x0i;
    x1i = wk1i * x0i - wk1r * x0r;
    x0r = a[offa + 14] + a[offa + 31];
    x0i = a[offa + 15] - a[offa + 30];
    x2r = wk3i * x0r - wk3r * x0i;
    x2i = wk3i * x0i + wk3r * x0r;
    y11r = x1r + x2r;
    y11i = x1i + x2i;
    y15r = x1r - x2r;
    y15i = x1i - x2i;
    x1r = y0r + y2r;
    x1i = y0i + y2i;
    x2r = y1r + y3r;
    x2i = y1i + y3i;
    a[offa] = x1r + x2r;
    a[offa + 1] = x1i + x2i;
    a[offa + 2] = x1r - x2r;
    a[offa + 3] = x1i - x2i;
    x1r = y0r - y2r;
    x1i = y0i - y2i;
    x2r = y1r - y3r;
    x2i = y1i - y3i;
    a[offa + 4] = x1r - x2i;
    a[offa + 5] = x1i + x2r;
    a[offa + 6] = x1r + x2i;
    a[offa + 7] = x1i - x2r;
    x1r = y4r - y6i;
    x1i = y4i + y6r;
    x0r = y5r - y7i;
    x0i = y5i + y7r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[offa + 8] = x1r + x2r;
    a[offa + 9] = x1i + x2i;
    a[offa + 10] = x1r - x2r;
    a[offa + 11] = x1i - x2i;
    x1r = y4r + y6i;
    x1i = y4i - y6r;
    x0r = y5r + y7i;
    x0i = y5i - y7r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[offa + 12] = x1r - x2i;
    a[offa + 13] = x1i + x2r;
    a[offa + 14] = x1r + x2i;
    a[offa + 15] = x1i - x2r;
    x1r = y8r + y10r;
    x1i = y8i + y10i;
    x2r = y9r - y11r;
    x2i = y9i - y11i;
    a[offa + 16] = x1r + x2r;
    a[offa + 17] = x1i + x2i;
    a[offa + 18] = x1r - x2r;
    a[offa + 19] = x1i - x2i;
    x1r = y8r - y10r;
    x1i = y8i - y10i;
    x2r = y9r + y11r;
    x2i = y9i + y11i;
    a[offa + 20] = x1r - x2i;
    a[offa + 21] = x1i + x2r;
    a[offa + 22] = x1r + x2i;
    a[offa + 23] = x1i - x2r;
    x1r = y12r - y14i;
    x1i = y12i + y14r;
    x0r = y13r + y15i;
    x0i = y13i - y15r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[offa + 24] = x1r + x2r;
    a[offa + 25] = x1i + x2i;
    a[offa + 26] = x1r - x2r;
    a[offa + 27] = x1i - x2i;
    x1r = y12r + y14i;
    x1i = y12i - y14r;
    x0r = y13r - y15i;
    x0i = y13i + y15r;
    x2r = wn4r * (x0r - x0i);
    x2i = wn4r * (x0i + x0r);
    a[offa + 28] = x1r - x2i;
    a[offa + 29] = x1i + x2r;
    a[offa + 30] = x1r + x2i;
    a[offa + 31] = x1i - x2r;
  }

  void cftf082(List<double> a, int offa, List<double> w, int startw) {
    double wn4r,
        wk1r,
        wk1i,
        x0r,
        x0i,
        x1r,
        x1i,
        y0r,
        y0i,
        y1r,
        y1i,
        y2r,
        y2i,
        y3r,
        y3i,
        y4r,
        y4i,
        y5r,
        y5i,
        y6r,
        y6i,
        y7r,
        y7i;

    wn4r = w[startw + 1];
    wk1r = w[startw + 2];
    wk1i = w[startw + 3];
    y0r = a[offa] - a[offa + 9];
    y0i = a[offa + 1] + a[offa + 8];
    y1r = a[offa] + a[offa + 9];
    y1i = a[offa + 1] - a[offa + 8];
    x0r = a[offa + 4] - a[offa + 13];
    x0i = a[offa + 5] + a[offa + 12];
    y2r = wn4r * (x0r - x0i);
    y2i = wn4r * (x0i + x0r);
    x0r = a[offa + 4] + a[offa + 13];
    x0i = a[offa + 5] - a[offa + 12];
    y3r = wn4r * (x0r - x0i);
    y3i = wn4r * (x0i + x0r);
    x0r = a[offa + 2] - a[offa + 11];
    x0i = a[offa + 3] + a[offa + 10];
    y4r = wk1r * x0r - wk1i * x0i;
    y4i = wk1r * x0i + wk1i * x0r;
    x0r = a[offa + 2] + a[offa + 11];
    x0i = a[offa + 3] - a[offa + 10];
    y5r = wk1i * x0r - wk1r * x0i;
    y5i = wk1i * x0i + wk1r * x0r;
    x0r = a[offa + 6] - a[offa + 15];
    x0i = a[offa + 7] + a[offa + 14];
    y6r = wk1i * x0r - wk1r * x0i;
    y6i = wk1i * x0i + wk1r * x0r;
    x0r = a[offa + 6] + a[offa + 15];
    x0i = a[offa + 7] - a[offa + 14];
    y7r = wk1r * x0r - wk1i * x0i;
    y7i = wk1r * x0i + wk1i * x0r;
    x0r = y0r + y2r;
    x0i = y0i + y2i;
    x1r = y4r + y6r;
    x1i = y4i + y6i;
    a[offa] = x0r + x1r;
    a[offa + 1] = x0i + x1i;
    a[offa + 2] = x0r - x1r;
    a[offa + 3] = x0i - x1i;
    x0r = y0r - y2r;
    x0i = y0i - y2i;
    x1r = y4r - y6r;
    x1i = y4i - y6i;
    a[offa + 4] = x0r - x1i;
    a[offa + 5] = x0i + x1r;
    a[offa + 6] = x0r + x1i;
    a[offa + 7] = x0i - x1r;
    x0r = y1r - y3i;
    x0i = y1i + y3r;
    x1r = y5r - y7r;
    x1i = y5i - y7i;
    a[offa + 8] = x0r + x1r;
    a[offa + 9] = x0i + x1i;
    a[offa + 10] = x0r - x1r;
    a[offa + 11] = x0i - x1i;
    x0r = y1r + y3i;
    x0i = y1i - y3r;
    x1r = y5r + y7r;
    x1i = y5i + y7i;
    a[offa + 12] = x0r - x1i;
    a[offa + 13] = x0i + x1r;
    a[offa + 14] = x0r + x1i;
    a[offa + 15] = x0i - x1r;
  }
}
