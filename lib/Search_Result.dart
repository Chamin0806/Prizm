// --no-sound-null-safety
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:platform_device_id/platform_device_id.dart';
import 'package:share_plus/share_plus.dart';
import 'chart/chart_container.dart';
import 'main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Result extends StatefulWidget {
  late final String id;

  Result({
    Key? key,
    required this.id,
  }) : super(key: key);

  @override
  _Result createState() => _Result();
}

class _Result extends State<Result> {
  String? _uid;
  String shareUrl = 'https://oneidlab.page.link/prizm';
  var maps;
  List programs = [];
  List song_cnts = [];

  var cnt;

  List reversedDate = [];
  List dateList = [];

  var intY;
  List listY = [];
  var intX;
  List listX = [];

  var dateTime;
  var date;
  var now = DateTime.now();
  var year;

  List<FlSpot> FlSpotDataAll = [];
  var sum;
  var avgY;

  void fetchData() async {
    // var search = MyApp.Uri['search'];
    // var program = MyApp.Uri['programs'];

    String? _uid;
    var deviceInfoPlugin = DeviceInfoPlugin();
    var deviceIdentifier = 'unknown';
    try {
      if (Platform.isAndroid) {
        _uid = await PlatformDeviceId.getDeviceId;
      } else if (Platform.isIOS) {
        var iosInfo = await deviceInfoPlugin.iosInfo;
        _uid = iosInfo.identifierForVendor!;
      }
    } on PlatformException {
      _uid = 'Failed to get Id';
    }
    // _uid = await PlatformDeviceId.getDeviceId;
    // print('uid : $_uid');

// json for title album artist

    try {
      http.Response response = await http.get(
          // Uri.parse('${MyApp.Uri}get_song_search/json?id=KE0012745001004&uid=11B9E7C3-4BF1-465B-B522-6158756CC737'));

          // Uri.parse('http://dev.przm.kr/przm_api/get_song_search/json?id=KE0012745001004&uid=11B9E7C3-4BF1-465B-B522-6158756CC737'));
      Uri.parse('http://${MyApp.search}/json?id=${widget.id}&uid=$_uid'));
      String jsonData = response.body;
      Map<String, dynamic> map = jsonDecode(jsonData);

      maps = map;
      song_cnts = maps['song_cnts'];

      setState(() {});
    } catch (e) {
      // print('json 가져오기 실패');
      print(e);
    }

//json for program list

    try {
      http.Response response = await http.get(
          Uri.parse('http://${MyApp.programs}/json?id=${widget.id}')
          // Uri.parse('http://dev.przm.kr/przm_api/get_song_programs/json?id=KE0012745001004')
    );
      String jsonData = response.body;

      programs = jsonDecode(jsonData.toString());
      setState(() {});
    } catch (e) {
      print(e);
    }

    try {
      List _contain = []; // 실데이타 파싱
      sum = 0;
      for (int i = 0; i <= song_cnts.length - 1; i++) {
        intX = int.parse(song_cnts[i]['F_MONTH'].toString());
        intY = int.parse(song_cnts[i]['CTN']);
        listX.add(intX);
        listY.add(intY);
        listX.sort();
        listY.sort();
        _contain.add(song_cnts[i]['F_MONTH'].toString());
        for (var y = 0; y < listY.length; y++) {
          sum += listY[y];
        }
      }
      avgY = sum / listY.length;

      List _dateList = [];
      var _dateTime;
      var _month;
      var _year;

//차트 x 축 기준 만들기
      for (var i = 1; i < 13; i++) {
        _dateTime = DateTime(now.year, now.month - i, 1);
        _month = DateFormat('MM').format(_dateTime);
        _year = DateFormat('yyyy').format(_dateTime);
        _dateList.add(_year + _month);
      }
      List _reverse = List.from(_dateList.reversed);

// 현재월
// 차트 실데이터 파싱
      for (int j = 0; j < _reverse.length; j++) {
//없는 월 제외
        double mon = double.parse(j.toString()) + 1;

        FlSpotDataAll.insert(j, FlSpot(mon, 0));
        for (int jj = 0; jj < song_cnts.length; jj++) {
          if (song_cnts[jj]['F_MONTH'].toString() == _reverse[j]) {
            cnt = double.parse(song_cnts[jj]['CTN']);
            FlSpotDataAll.removeAt(j);
            FlSpotDataAll.insert(j, FlSpot(mon, cnt));
          }
        }
      }
      FlSpotDataAll.removeWhere((items) => items.props.contains(0.0));
    } catch (e) {
      print('fail to make FlSpotData');
      print(e);
    }
  }

  Future<void> logSetscreen() async {
    await MyApp.analytics.setCurrentScreen(screenName: '검색결과');
    await MyApp.analytics.logEvent(name: 'Title');
  }

  final duplicateItems =
      List<String>.generate(1000, (i) => "$Container(child:Text $i)");
  var items = <String>[];

  Future<void> remoteConfig() async { //Firebase remoteConfig에서 shareUrl변경 후 게시하면 변경된 Url로 공유 
    final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

    remoteConfig.setDefaults({'shareUrl':shareUrl});
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero)
    );
    await remoteConfig.fetchAndActivate();
    String remoteUrl = remoteConfig.getString('shareUrl');
    shareUrl = remoteUrl;
  }

  @override
  void initState() {
    HapticFeedback.vibrate(); //검색 완료시 진동 현재 Android만
    remoteConfig();
    logSetscreen();
    fetchData();
    // getLink();
    super.initState();
  }

  @override
  void dispose() {
    print('dispose');
    line_chart(song_cnts);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setEnabledSystemUIMode(// 상하단 상태바 제거
        SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
    double c_height = MediaQuery.of(context).size.height * 1.0;
    double c_width = MediaQuery.of(context).size.width * 1.0;
    final isCNTS = song_cnts.length > 3;
    final isExist = programs.length == 0;
    final isArtistNull = maps['ARTIST'] == null;
    final isAlbumNull = maps['ALBUM'] == null;
    final isImage = maps['IMAGE'].toString().startsWith('assets') != true;
    final isPad = c_width > 800;
    final isFlip = c_height / c_width > 2.3;
    final isUltra = c_height > 1000;
    final isPlus = 1000 < c_height && 1300 >= c_height && c_width > 500;
    final isNormal = c_height < 850;
    return WillPopScope(
      onWillPop: () async {
        return _onBackKey();
      },
      child: Scrollbar(
        child: SizedBox(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Material(
                color: isDarkMode ? Colors.black : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Center(
                          child: isFlip
                              ? SizedBox(
                                  child: Image.network(
                                  '${maps['IMAGE']}',
                                  height: c_height * 0.57,
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
                                    return SizedBox(
                                      child: Image.asset(
                                        'assets/no_image.png',
                                        height: c_height * 0.57,
                                        fit: BoxFit.fill,
                                      ),
                                    );
                                  },
                                )) // << flip
                              : isPad
                                  ? SizedBox(
                                      child: Image.network(
                                      '${maps['IMAGE']}',
                                      height: c_height * 0.5,
                                      width: c_height * 0.5,
                                      fit: BoxFit.fill,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return SizedBox(
                                          child: Image.asset(
                                            'assets/no_image.png',
                                            height: c_height * 0.5,
                                            fit: BoxFit.fill,
                                          ),
                                        );
                                      },
                                    )) //  << fold
                                  : isPlus
                                      ? SizedBox(
                                          child: Image.network(
                                          '${maps['IMAGE']}',
                                          width: c_width,
                                          height: c_height * 0.4,
                                          fit: BoxFit.fill,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return SizedBox(
                                              child: Image.asset(
                                                'assets/no_image.png',
                                                height: c_height * 0.4,
                                                fit: BoxFit.fill,
                                              ),
                                            );
                                          },
                                        ))
                                      : isUltra
                                          ? SizedBox(
                                              child: Image.network(
                                              '${maps['IMAGE']}',
                                              height: c_height * 0.5,
                                              fit: BoxFit.fill,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return SizedBox(
                                                  child: Image.asset(
                                                    'assets/no_image.png',
                                                    height: c_height * 0.5,
                                                    fit: BoxFit.fill,
                                                  ),
                                                );
                                              },
                                            ))
                                          : isNormal
                                              ? SizedBox(
                                                  child: Image.network(
                                                  '${maps['IMAGE']}',
                                                  height: c_height * 0.6,
                                                  fit: BoxFit.fill,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return SizedBox(
                                                      child: Image.asset(
                                                        'assets/no_image.png',
                                                        height: c_height * 0.6,
                                                        fit: BoxFit.fill,
                                                      ),
                                                    );
                                                  },
                                                ))
                                              : SizedBox(
                                                  child: Image.network(
                                                  '${maps['IMAGE']}',
                                                  height: c_height * 0.5,
                                                  fit: BoxFit.fill,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return SizedBox(
                                                      child: Image.asset(
                                                        'assets/no_image.png',
                                                        height: c_height * 0.5,
                                                        fit: BoxFit.fill,
                                                      ),
                                                    );
                                                  },
                                                )),
                        ),
                        Container(
                          decoration: BoxDecoration(
                              gradient: isDarkMode
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black12, Colors.black],
                                      stops: [.35, .75])
                                  : const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.white10, Colors.white],
                                      stops: [.35, .75])),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon:
                                        const Icon(Icons.arrow_back_ios_sharp),
                                    color: isImage
                                        ? isDarkMode
                                            ? Colors.white
                                            : Colors.black
                                        : isPad
                                            ? isDarkMode
                                                ? Colors.white
                                                : Colors.black
                                            : isDarkMode
                                                ? Colors.black
                                                : Colors.black,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => TabPage()),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share_outlined,
                                      size: 30,
                                    ),
                                    color: isImage
                                        ? isDarkMode
                                            ? Colors.white
                                            : Colors.black
                                        : isPad
                                            ? isDarkMode
                                                ? Colors.white
                                                : Colors.black
                                            : isDarkMode
                                                ? Colors.black
                                                : Colors.black,
                                    onPressed: () async {
                                      await MyApp.analytics.logEvent(
                                          name: 'ShareButton',
                                          parameters: null);
                                      _onShare(context);
                                    },
                                  )
                                ],
                              ),
                              Container(
                                  margin: EdgeInsets.only(top: isPad ? 500 : 400),
                                  // margin: EdgeInsets.only(top:400),
                                  width: c_width * 0.9,
                                  child: RichText(
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    strutStyle: const StrutStyle(fontSize: 30),
                                    text: TextSpan(children: [
                                      TextSpan(
                                        text: '${maps['TITLE']}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 30,
                                            overflow: TextOverflow.ellipsis,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black),
                                      )
                                    ]),
                                  )),
                              Container(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Row(
                                    children: [
                                      Flexible(
                                          child: RichText(
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        strutStyle:
                                            const StrutStyle(fontSize: 17),
                                        text: TextSpan(children: [
                                          TextSpan(
                                            text: isArtistNull
                                                ? 'Various Artist'
                                                : maps['ARTIST'],
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          TextSpan(
                                              text: ' · ',
                                              style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.grey
                                                      : Colors.black
                                                          .withOpacity(0.4),
                                                  fontSize: 17)),
                                          TextSpan(
                                            text: isAlbumNull
                                                ? 'Various Album'
                                                : maps['ALBUM'],
                                            style: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.grey
                                                    : Colors.black
                                                        .withOpacity(0.4),
                                                overflow: TextOverflow.ellipsis,
                                                fontSize: 17),
                                          )
                                        ]),
                                      ))
                                    ],
                                  )),
                              Container(
                                margin: const EdgeInsets.fromLTRB(0, 10, 0, 50),
                                child: Row(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 20),
                                      padding: const EdgeInsets.fromLTRB(
                                          10, 5, 10, 5),
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          color: const Color.fromRGBO(
                                              51, 211, 180, 1)),
                                      child: Text(
                                        '${maps['date']}',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    Image.asset('assets/result_search.png',
                                        width: 15, color: Colors.grey),
                                    Text(' ${maps['count']}',
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            overflow: TextOverflow.ellipsis)),
                                    const Text('회',
                                        style: TextStyle(color: Colors.grey))
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                        margin: const EdgeInsets.only(right: 20, left: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              color: isDarkMode ? Colors.black : Colors.white,
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                              child: const Text('최신 방송 재생정보',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                            ),
                            SizedBox(
                                height: 250,
                                child: Container(
                                    child: isExist
                                        ? Center(
                                            child: Text('최신 방송 재생정보가 없습니다.',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20)))
                                        : Row(
                                            children: [_listView(programs)],
                                          ))),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    margin: const EdgeInsets.only(bottom: 30),
                                    child: const Text(
                                      '프리즘차트',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20),
                                    )),
                                isCNTS
                                    ? ChartContainer(
                                        color: isDarkMode
                                            ? Colors.black
                                            : Colors.white,
                                        chart: line_chart(song_cnts),
                                        title: '',
                                      )
                                    : const SizedBox(
                                        height: 200,
                                        child: Center(
                                            child: Text('차트 정보가 없습니다.',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20))))
                              ],
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.only(left: 00, right: 10),
                              decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color.fromRGBO(42, 42, 42, 1)
                                      : const Color.fromRGBO(250, 250, 250, 1)),
                              height: 100,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/result_search.png',
                                      width: 20),
                                  Container(
                                    margin: const EdgeInsets.only(
                                        left: 10, right: 10),
                                    // padding: const EdgeInsets.only(right: 10),
                                    child: Text('총 검색 : ',
                                        style: TextStyle(
                                            fontSize: 17,
                                            color: isDarkMode
                                                ? const Color.fromRGBO(
                                                    151, 151, 151, 1)
                                                : Colors.black)),
                                  ),
                                  Text('${maps['count']}',
                                      style: const TextStyle(fontSize: 17)),
                                  const Text('회',
                                      style: TextStyle(fontSize: 17))
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _onBackKey();
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 100),
                                height: 70,
                                margin:
                                    const EdgeInsets.fromLTRB(0, 30, 10, 40),
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        width: 1,
                                        color: isDarkMode
                                            ? Colors.grey.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.1))),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                        padding:
                                            const EdgeInsets.only(right: 10),
                                        child: const Text(
                                          '홈으로',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        )),
                                    Icon(
                                      Icons.arrow_forward_ios_sharp,
                                      size: 17,
                                      color: isDarkMode
                                          ? const Color.fromRGBO(
                                              125, 125, 125, 1)
                                          : const Color.fromRGBO(
                                              208, 208, 208, 1),
                                    )
                                  ],
                                ),
                              ),
                            )
                          ],
                        ))
                  ],
                )),
          ),
        ),
      ),
    );
  }

  Widget _listView(programs) {
    return Expanded(
      child: ListView.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: programs == null ? 0 : programs.length,
          itemBuilder: (context, index) {
            final program = programs[index];

            String programDate = program['F_DATE'];
            String parseProgramDate = DateFormat('yyyy.MM.dd')
                .format(DateTime.parse(programDate))
                .toString();

            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      padding: const EdgeInsets.all(1),
                      margin: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          width: 3,
                          color: isDarkMode
                              ? const Color.fromRGBO(189, 189, 189, 1)
                              // : const Color.fromRGBO(228, 228, 228, 1),
                              : Colors.black.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox.fromSize(
                          child: Image.network(
                            // program['F_IMAGE'],
                            program['F_LOGO'],
                            width: 140,
                            height: 140,
                            errorBuilder: (context, stackTrace, error) {
                              return SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: Image.asset('assets/no_image.png'));
                            },
                          ),
                        ),
                      )),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            margin: const EdgeInsets.only(right: 0),
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color.fromRGBO(51, 211, 180, 1)),
                            child: Text(
                              program['F_TYPE'],
                              style: const TextStyle(
                                  color: Colors.white,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          Container(
                              margin: const EdgeInsets.only(left: 10),
                              width: 65,
                              height: 22,
                              child: Text(program['CL_NM'],
                                  style: TextStyle(
                                      fontSize: 16,
                                      overflow: TextOverflow.ellipsis,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black))
                              // child: Image.network(
                              //   program['F_LOGO'],
                              //   width: 50,
                              //   height: 22,
                              //   errorBuilder: (context, error, stackTrace) {
                              //     return SizedBox(
                              //         width: 65,
                              //         height: 22,
                              //         child: Text(program['CL_NM'],
                              //             style: TextStyle(
                              //                 fontSize: 16,
                              //                 overflow: TextOverflow.ellipsis,
                              //                 fontWeight: FontWeight.bold,
                              //                 color: isDarkMode
                              //                     ? Colors.white
                              //                     : Colors.black)
                              //         )
                              //     );
                              //   },
                              // ),
                              )
                        ]),
                        Container(
                          margin: const EdgeInsets.fromLTRB(0, 3, 0, 10),
                          width: 135,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 3),
                                child: Text(program['F_NAME'],
                                    style: const TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                              Text(parseProgramDate,
                                  style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.grey.withOpacity(0.8)
                                          : Colors.black.withOpacity(0.3))),
                            ],
                          ),
                        )
                      ])
                ],
              )
            ]);
          }),
    );
  }

  Future<bool> _onBackKey() async {
    return await showDialog(
        context: context,
        builder: (BuildContext context) {
          return TabPage();
        });
  }

  void _onShare(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;

    if (Platform.isIOS) {
      await Share.share(
          // 'https://oneidlab.page.link/prizmios',
        '${shareUrl}ios',
        subject: 'Prizm',
          sharePositionOrigin: Rect.fromLTRB(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height * 0.5),
      );
    } else if (Platform.isAndroid) {
      // await Share.share('https://oneidlab.page.link/prizm',
          await Share.share(shareUrl,
          subject: 'Prizm'
      ); // 짧은 동적링크
      // https://oneidlab.page.link/?link=https://oneidlab.page.link/prizm%26apn%3Dcom.android.prizm&apn=com.android.prizm[&afl='Play Store Url'] << 앱 설치x일때 스토어로 보내기
      // await Share.share('https://oneidlab.page.link/?link=https://oneidlab.page.link/prizm%26apn%3Dcom.android.prizm&apn=com.android.prizm', subject: 'Prizm'); //긴 동적링크
    }
    // box!.localToGlobal(Offset.zero) & box.size);
  }

  late String text;

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    text = '';

    try {
      int i = 1;
      dateList = [];
      for (i; i < 13; i++) {
        dateTime = DateTime(now.year, now.month - i, 1);
        date = DateFormat('MM').format(dateTime);
        year = DateFormat('yy').format(now);
// print(dateTime);

        dateList.add(date);
      }
    } catch (e) {
      print('bottom title : $e');
    }
    reversedDate = [];
    reversedDate = List.from(dateList.reversed);

    switch (value.toInt()) {
      case 1:
        text = reversedDate[0];
        break;
      case 2:
        text = reversedDate[1];
        break;
      case 3:
        text = reversedDate[2];
        break;
      case 4:
        text = reversedDate[3];
        break;
      case 5:
        text = reversedDate[4];
        break;
      case 6:
        text = reversedDate[5];
        break;
      case 7:
        text = reversedDate[6];
        break;
      case 8:
        text = reversedDate[7];
        break;
      case 9:
        text = reversedDate[8];
        break;
      case 10:
        text = reversedDate[9];
        break;
      case 11:
        text = reversedDate[10];
        break;
      default:
        text = reversedDate[11];
        break;
    }
    return SideTitleWidget(axisSide: meta.axisSide, child: Text(text));
  }

  Widget line_chart(song_cnts) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    List<FlSpot> FlSpotData = [];
    FlSpotData.addAll(FlSpotDataAll);
    final minCnt = listY.last >= 50;

    var result = LineChart(LineChartData(
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
                y: 0,
                color: isDarkMode
                    ? Colors.grey.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.3))
          ],
        ),
        baselineY: 0,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
            getDrawingHorizontalLine: (value) {
              return FlLine(
                  strokeWidth: 1,
                  color: isDarkMode
                      ? Colors.grey.withOpacity(0.6)
                      : Colors.grey.withOpacity(0.3));
            },
            drawVerticalLine: false,
            drawHorizontalLine: true,
            horizontalInterval: minCnt ? avgY / 8 : 30),
        minX: 1,
        minY: 0,
        maxX: 12,
        maxY: double.parse((listY.last).toString()) + 100,
        lineBarsData: [
          LineChartBarData(
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                        radius: 3.0,
                        color: const Color.fromRGBO(51, 211, 180, 1),
                        strokeColor:
                            isDarkMode ? Colors.white : Colors.grey.shade200,
                        strokeWidth: 5.0),
              ),
              color: const Color.fromRGBO(51, 211, 180, 1),
              isCurved: true,
              curveSmoothness: 0.1,
              barWidth: 3,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: isDarkMode
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                            Color.fromRGBO(51, 215, 180, 1),
                            Colors.white10
                          ])
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                            Color.fromRGBO(51, 215, 180, 1),
                            Colors.white24
                          ]),
              ),
              spots: FlSpotData)
        ],
        titlesData: FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: bottomTitleWidgets)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
        lineTouchData: LineTouchData(enabled: true)));
    return result;
  }
}

void avocado() {
  var milk;
  var avocado;
  if(avocado == true) { //아보카도 있어?
    milk == 6; //있어서 우유 6개
  } else if(milk == true) { // 우유 사와
    if(avocado == true) { // 아보카도 있어?
      avocado == 6; // 있으니까 6개
    } else {
      avocado == 0;
    }
  }
}