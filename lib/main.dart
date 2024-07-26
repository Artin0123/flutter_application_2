import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// void callbackDispatcher() {
//   Workmanager().executeTask((taskName, inputData) {
//     // 在這裡編寫你的後台任務代碼
//     print("Background task executed");
//     // 如果需要執行耗時操作,可以在這裡調用其他函數或方法

//     return Future.value(true);
//   });
// }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  // 註冊持續定期任務
  // await Workmanager().registerPeriodicTask(
  //   "1", // 任務的唯一名稱
  //   "simplePeriodicTask", // 要執行的任務名稱
  //   frequency: Duration(minutes: 5), // 執行頻率
  //   existingWorkPolicy: ExistingWorkPolicy.replace,
  // );
  runApp(
    ChangeNotifierProvider(
      create: (context) => WebSocketService(),
      child: const MyApp(),
    ),
  );
}

void fetchData() async {
  final response = await http.get(Uri.http('firealert.waziwazi.top:8880', 'device-list'));

  if (response.statusCode == 200) {
    // If the server returns a 200 OK response,
    // then parse the JSON.
    print('Response data: ${response.body}');
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.

    throw Exception('Failed to load data');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '火燒報哩災',
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int currentIndex = 0;
  final List<Widget> pages = [
    const PageEvent(),
    const PageHistory(),
    const PageWarn(),
    const PageUtil(),
    const PageSetting(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: pages[currentIndex],
        bottomNavigationBar: ConvexAppBar(
          // selectedItemColor: Color.fromARGB(255, 51, 66, 80),
          // unselectedItemColor: Colors.grey,
          // showUnselectedLabels: true,
          // currentIndex: currentIndex,
          style: TabStyle.react,
          // cornerRadius: 20,
          backgroundColor: Colors.blue[400],
          elevation: 3,
          color: Colors.grey[100],
          activeColor: Colors.blue[900],
          onTap: (int index) {
            setState(() {
              currentIndex = index;
            });
          },
          items: const [
            TabItem(
              icon: Icons.home,
              title: '事件',
            ),
            TabItem(
              icon: Icons.history,
              title: '歷史',
            ),
            TabItem(
              icon: Icons.warning,
              title: '通報',
            ),
            TabItem(
              icon: Icons.smart_toy,
              title: '設備',
            ),
            TabItem(
              icon: Icons.settings,
              title: '設定',
            ),
          ],
        ));
  }
}

// -----SensorData1------
class SensorData {
  String airQuality = '';
  String temperature = '';
  String id = '';
  String iot_id = ''; //設備是否正常
  String locations = '';
  String updatetime = '';
  String events = ''; //事件種類
  String levels = ''; //事件等級
  String isAlert = ''; //是否有警報
  SensorData(this.airQuality, this.temperature, this.id, this.iot_id, this.locations, this.events, this.isAlert, this.levels, this.updatetime);
  SensorData.defaults()
      : airQuality = '',
        temperature = '',
        id = '',
        iot_id = '',
        locations = '',
        updatetime = '',
        events = '',
        levels = '',
        isAlert = '';

  void modify(SensorData buffer) {
    airQuality = buffer.airQuality;
    temperature = buffer.temperature;
    id = buffer.id;
    iot_id = buffer.iot_id;
    locations = buffer.locations;
    updatetime = buffer.updatetime;
    events = buffer.events;
    levels = buffer.levels;
    isAlert = buffer.levels;
  }

  static int compareByLevel(SensorData a, SensorData b) {
    //兩個sensorData比大小
    int levelA = int.tryParse(a.levels) ?? 0;
    int levelB = int.tryParse(b.levels) ?? 0;
    return levelB.compareTo(levelA);
  }
}

List<SensorData> sensordata = [];
List<SensorData> record = [];
// -----SensorData2------

// -----WebSocket1-----
class WebSocketService with ChangeNotifier {
  late WebSocketChannel _channel;
  late StreamController<Map<String, dynamic>> _messageController2;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  WebSocketService() {
    _messageController2 = StreamController<Map<String, dynamic>>.broadcast();
    _connectToWebSocket();
    _initializeNotifications();
  }

  Stream<Map<String, dynamic>> get messageStream => _messageController2.stream;

  void _connectToWebSocket() async {
    while (true) {
      try {
        _channel = WebSocketChannel.connect(Uri.parse(
            'ws://firealert.waziwazi.top:8880?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJqb2huIiwiaWF0IjoxNzE1MDc2MDAxLCJleHAiOjE3MzA2MjgwMDF9.5sV4-QHxKTsg6MgoJ6CXaMuk_LacQaptPXSolqMnZL4&uid=10011'));
        _channel.stream.listen(
          (message) {
            var data = json.decode(message.toString());
            if (data['status'] == 'success') {
              debugPrint('Connection established successfully');
              debugPrint(message);
            } else {
              debugPrint(message);
            }
            _messageController2.add(data);
            _showNotification(data);
            notifyListeners();
          },
          onError: (error) {
            debugPrint('WebSocket Error: $error');
          },
        );
        break;
      } catch (e) {
        debugPrint('WebSocket Connection Error: $e');
        await Future.delayed(const Duration(seconds: 5)); // 等待5秒後再次嘗試連接
      }
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'New Message',
      data.toString(),
      platformChannelSpecifics,
    );
  }
}
// -----WebSocket2-----

class PageEvent extends StatefulWidget {
  const PageEvent({super.key});
  @override
  State<PageEvent> createState() => _PageEvent();
}

class _PageEvent extends State<PageEvent> {
  late final WebSocketService _streamControllerJson;

  @override
  void initState() {
    super.initState();
    try {
      _streamControllerJson = Provider.of<WebSocketService>(context, listen: false);
    } catch (e) {
      debugPrint('Error initializing WebSocketService: $e');
    }
  }

  printdata() {
    for (var i = 0; i < sensordata.length; i++) {
      debugPrint(sensordata[i].id);
    }
  }

  SensorData sensorData = SensorData.defaults();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
          backgroundColor: Colors.blue[400],
          title: Text('火災事件列表', style: TextStyle(color: Colors.grey[50], fontSize: 28, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3.0),
            child: Container(
              color: Colors.blue[700],
              height: 3.0,
            ),
          )),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _streamControllerJson.messageStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Data is available, extract and display it
            Map<String, dynamic> datas = snapshot.data!;
            if (datas.containsKey('details')) {
              dynamic data = datas['details'];
              if (data.isNotEmpty) {
                String locations = data['location'];
                String levels = data['level'].toString();
                String temperatures = data['temperature'].toString();
                String timestamps = data['o_time_stamp'].toString();
                String airqualitys = data['smoke'].toString();
                String events = data['event'].toString();
                String eventId = data['event_id'].toString();
                String bigLocation = data['group_name'];
                String iotId = data['iot_id'].toString();
                String isAlert = data['is_alert'].toString();
                sensorData = SensorData(airqualitys, temperatures, eventId, iotId, '$bigLocation $locations', events, isAlert, levels, timestamps);
                int spi = 0;
                for (var i = 0; i < sensordata.length; i++) {
                  if (sensordata[i].iot_id == iotId) {
                    sensordata[i].modify(sensorData);
                    spi = 1;
                    break;
                  }
                }
                if (spi == 0) {
                  sensordata.add(sensorData);
                }
                record.add(sensorData);
              }
            }
            return SingleChildScrollView(
              child: sensordata.isEmpty
                  ? SizedBox(
                      width: 400, // 设置固定宽度
                      height: 100, // 设置固定高度
                      child: Card(
                        elevation: 6,
                        margin: const EdgeInsets.all(16),
                        color: Colors.white, // 设置白色背景
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0), // 设置圆角
                          side: const BorderSide(color: Colors.black, width: 2.0), // 设置黑色边框
                        ),
                        child: const Center(
                          child: Text(
                            '無事件資料',
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true, // Ensures that the ListView.builder takes up only the necessary space
                      itemCount: sensordata.length,
                      itemBuilder: (context, index) {
                        SensorData itemData = sensordata[index];
                        //加入顏色變化
                        //判斷event類別
                        return Card(
                          elevation: 6,
                          margin: const EdgeInsets.all(16),
                          color: const Color.fromARGB(255, 253, 208, 223),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            side: const BorderSide(
                              color: Color.fromARGB(248, 237, 127, 167),
                              width: 3.0,
                            ),
                          ),
                          child: Row(
                            // crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(
                                width: 320,
                                child: ListTile(
                                  title: Padding(
                                    padding: const EdgeInsets.only(top: 5), // 添加間距
                                    child: Text(
                                      itemData.events,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const SizedBox(height: 5), // 添加間距
                                      Text(
                                        '${itemData.locations}\n'
                                        '${itemData.updatetime}\n',
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(fontSize: 16, height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.keyboard_arrow_right),
                                iconSize: 48,
                                color: const Color.fromARGB(248, 241, 102, 153),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => DetailPage(sensorData_detail: itemData)),
                                  );
                                },
                                alignment: Alignment.centerRight,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            );
          } else if (snapshot.hasError) {
            // Error occurred while fetching data
            return Center(
              child: Text('WebSocket Error: ${snapshot.error}'),
            );
          } else {
            // Data is not available yet
            if (sensordata.isEmpty) {
              //return (Text('無事件資料'));
              return SizedBox(
                width: 400, // 设置固定宽度
                height: 100, // 设置固定高度
                child: Card(
                  elevation: 6,
                  margin: const EdgeInsets.all(16),
                  color: Colors.white, // 设置白色背景
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0), // 设置圆角
                    side: const BorderSide(color: Colors.black, width: 2.0), // 设置黑色边框
                  ),
                  child: const Center(
                    child: Text(
                      '無事件資料',
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              );
            } else {
              return ListView.builder(
                shrinkWrap: true, // Ensures that the ListView.builder takes up only the necessary space
                itemCount: sensordata.length,
                itemBuilder: (context, index) {
                  SensorData itemData = sensordata[index];
                  //加入顏色變化
                  //判斷event類別
                  return Card(
                    elevation: 6,
                    margin: const EdgeInsets.all(16),
                    color: const Color.fromARGB(255, 253, 208, 223),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: const BorderSide(
                        color: Color.fromARGB(248, 237, 127, 167),
                        width: 3.0,
                      ),
                    ),
                    child: Row(
                      // crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 320,
                          child: ListTile(
                            title: Padding(
                              padding: const EdgeInsets.only(top: 5), // 添加間距
                              child: Text(
                                itemData.events,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const SizedBox(height: 5), // 添加間距
                                Text(
                                  '${itemData.locations}\n'
                                  '${itemData.updatetime}\n',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(fontSize: 16, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_right),
                          iconSize: 48,
                          color: const Color.fromARGB(248, 241, 102, 153),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => DetailPage(sensorData_detail: itemData)),
                            );
                          },
                          alignment: Alignment.centerRight,
                        ),
                      ],
                    ),
                  );
                },
              );
            }
            // Or any other loading indicator
          }
        },
      ),
    );
  }
}

class PageHistory extends StatefulWidget {
  const PageHistory({super.key});
  @override
  State<PageHistory> createState() => _PageHistory();
}

class _PageHistory extends State<PageHistory> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.blue[400],
          title: Text('歷史紀錄', style: TextStyle(color: Colors.grey[50], fontSize: 28, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3.0),
            child: Container(
              color: Colors.blue[700],
              height: 3.0,
            ),
          )),
      body: Center(
        child: Column(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PageArgs()),
                );
              },
            ),
            ElevatedButton(
              onPressed: fetchData,
              child: Text('Fetch Data'),
            ),
          ],
        ),
      ),
    );
  }
}

class PageWarn extends StatefulWidget {
  const PageWarn({super.key});
  @override
  State<PageWarn> createState() => _PageWarn();
}

class _PageWarn extends State<PageWarn> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.blue[400],
          title: Text('緊急通報', style: TextStyle(color: Colors.grey[50], fontSize: 28, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3.0),
            child: Container(
              color: Colors.blue[700],
              height: 3.0,
            ),
          )),
      body: const Center(
        child: Text('通報'),
      ),
    );
  }
}

class PageUtil extends StatefulWidget {
  const PageUtil({super.key});
  @override
  State<PageUtil> createState() => _PageUtil();
}

class _PageUtil extends State<PageUtil> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextField(
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: const Center(
        child: Text('設備'),
      ),
    );
  }
}

class PageSetting extends StatefulWidget {
  const PageSetting({super.key});
  @override
  State<PageSetting> createState() => _PageSetting();
}

class _PageSetting extends State<PageSetting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[400],
        title: Text('設定', style: TextStyle(color: Colors.grey[50], fontSize: 28, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: Container(
            color: Colors.blue[700],
            height: 3.0,
          ),
        ),
      ),
      body: const Center(
        child: Text('設定'),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final SensorData sensorData_detail;
  const DetailPage({super.key, required this.sensorData_detail});
  @override
  State<DetailPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<DetailPage> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  late final SensorData _sensorData = SensorData.defaults();

  @override
  void initState() {
    super.initState();
    _sensorData.modify(widget.sensorData_detail);
    _controller = VideoPlayerController.network(
      'https://yzulab1.waziwazi.top/stream?token=123456',
    );

    _initializeVideoPlayerFuture = _controller.initialize();

    _controller.setLooping(true);

    // Add listener to update state and rebuild UI when playing
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('詳細資料'), // 更改成影片頁面的標題
        ),
        body: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.all(10), // 添加間距
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.blueGrey[700] ?? Colors.blue, width: 2), // 添加邊框
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Padding(
                    padding: const EdgeInsets.only(top: 5), // 添加間距
                    child: Text(
                      _sensorData.events,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 5), // 添加間距
                      Text(
                        '位置: ${_sensorData.locations}\n'
                        '時間: ${_sensorData.updatetime}\n'
                        '事件等級: ${_sensorData.levels}\n'
                        '• 設備編號: ${_sensorData.iot_id}\n'
                        '• 煙霧參數: ${_sensorData.airQuality} (正常值: 10)\n'
                        '• 溫度參數: ${_sensorData.temperature}°C\n',
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FutureBuilder(
              future: _initializeVideoPlayerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3, //改變影片展示大小
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            double videoWidth = constraints.maxWidth;
                            double videoHeight = videoWidth * (3 / 4);
                            return SizedBox(
                              width: videoWidth,
                              height: videoHeight,
                              child: VideoPlayer(_controller),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.blue,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue[400],
                    ),
                  );
                }
              },
            ),
            FloatingActionButton(
              backgroundColor: Colors.blue[400],
              onPressed: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ],
        ));
  }
}

class PageArgs extends StatefulWidget {
  const PageArgs({super.key});
  @override
  State<PageArgs> createState() => _PageArgs();
}

class _PageArgs extends State<PageArgs> {
  String _selectedLabel = '1';
  bool warning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('參數設定'), // 更改成影片頁面的標題
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.all(10), // 添加間距
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.blueGrey[700] ?? Colors.blue, width: 2), // 添加邊框
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const ListTile(
                    title: Padding(
                      padding: EdgeInsets.only(top: 5), // 添加間距
                      child: Text(
                        "元智一館 七樓 1705A實驗室",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(height: 5), // 添加間距
                        Text(
                          '狀態：正常\n'
                          '上次回應： 2024-11-13 22 : 07\n'
                          'IP 地址: 192.168.70.99\n'
                          '\n'
                          '• 設備編號: 100\n'
                          '• 感測煙霧: 43 ug/m3\n'
                          '• 感測溫度: 29.3 °C\n',
                          textAlign: TextAlign.left,
                          style: TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(10), // 添加間距
                child: ListTile(
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Text(
                            '• 名稱設定: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          Flexible(
                            // flex: 1,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: ' 請輸入文字',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      const Row(
                        children: <Widget>[
                          Text(
                            '• 群組設定: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          Flexible(
                            // flex: 1,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: ' 請輸入文字',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      Row(
                        children: <Widget>[
                          const Text(
                            '• 設備啟用: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          Switch(
                            value: warning,
                            onChanged: (bool value) {
                              setState(() {
                                warning = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      Row(
                        children: <Widget>[
                          const Text(
                            '• 煙霧閥值: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          DropdownMenu(
                            enableFilter: true,
                            onSelected: (number) {
                              // This is called when the user selects an item.
                              setState(() {
                                _selectedLabel = number.toString();
                              });
                            },
                            dropdownMenuEntries: const <DropdownMenuEntry<int>>[
                              DropdownMenuEntry<int>(
                                value: 1,
                                label: '1',
                              ),
                              DropdownMenuEntry<int>(
                                value: 2,
                                label: '2',
                              ),
                              DropdownMenuEntry<int>(
                                value: 3,
                                label: '3',
                              ),
                              DropdownMenuEntry<int>(
                                value: 4,
                                label: '4',
                              ),
                              DropdownMenuEntry<int>(
                                value: 5,
                                label: '5',
                              ),
                            ],
                          ),
                          const Text(
                            ' ( μg/m3 )',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      Row(
                        children: <Widget>[
                          const Text(
                            '• 煙敏感度: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          DropdownMenu(
                            enableFilter: true,
                            onSelected: (number) {
                              // This is called when the user selects an item.
                              setState(() {
                                _selectedLabel = number.toString();
                              });
                            },
                            dropdownMenuEntries: const <DropdownMenuEntry<int>>[
                              DropdownMenuEntry<int>(
                                value: 1,
                                label: '1',
                              ),
                              DropdownMenuEntry<int>(
                                value: 2,
                                label: '2',
                              ),
                              DropdownMenuEntry<int>(
                                value: 3,
                                label: '3',
                              ),
                              DropdownMenuEntry<int>(
                                value: 4,
                                label: '4',
                              ),
                              DropdownMenuEntry<int>(
                                value: 5,
                                label: '5',
                              ),
                            ],
                          ),
                          const Text(
                            ' ( % / 30秒 )',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      Row(
                        children: <Widget>[
                          const Text(
                            '• 溫度閥值: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          DropdownMenu(
                            enableFilter: true,
                            onSelected: (number) {
                              // This is called when the user selects an item.
                              setState(() {
                                _selectedLabel = number.toString();
                              });
                            },
                            dropdownMenuEntries: const <DropdownMenuEntry<int>>[
                              DropdownMenuEntry<int>(
                                value: 1,
                                label: '1',
                              ),
                              DropdownMenuEntry<int>(
                                value: 2,
                                label: '2',
                              ),
                              DropdownMenuEntry<int>(
                                value: 3,
                                label: '3',
                              ),
                              DropdownMenuEntry<int>(
                                value: 4,
                                label: '4',
                              ),
                              DropdownMenuEntry<int>(
                                value: 5,
                                label: '5',
                              ),
                            ],
                          ),
                          const Text(
                            ' ( ℃ )',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      Row(
                        children: <Widget>[
                          const Text(
                            '• 熱敏感度: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          DropdownMenu(
                            enableFilter: true,
                            onSelected: (number) {
                              // This is called when the user selects an item.
                              setState(() {
                                _selectedLabel = number.toString();
                              });
                            },
                            dropdownMenuEntries: const <DropdownMenuEntry<int>>[
                              DropdownMenuEntry<int>(
                                value: 1,
                                label: '1',
                              ),
                              DropdownMenuEntry<int>(
                                value: 2,
                                label: '2',
                              ),
                              DropdownMenuEntry<int>(
                                value: 3,
                                label: '3',
                              ),
                              DropdownMenuEntry<int>(
                                value: 4,
                                label: '4',
                              ),
                              DropdownMenuEntry<int>(
                                value: 5,
                                label: '5',
                              ),
                            ],
                          ),
                          const Text(
                            ' ( % / 30秒 )',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      Row(
                        children: <Widget>[
                          const Text(
                            '• 錄影時長: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                          DropdownMenu(
                            enableFilter: true,
                            onSelected: (number) {
                              // This is called when the user selects an item.
                              setState(() {
                                _selectedLabel = number.toString();
                              });
                            },
                            dropdownMenuEntries: const <DropdownMenuEntry<int>>[
                              DropdownMenuEntry<int>(
                                value: 1,
                                label: '1',
                              ),
                              DropdownMenuEntry<int>(
                                value: 2,
                                label: '2',
                              ),
                              DropdownMenuEntry<int>(
                                value: 3,
                                label: '3',
                              ),
                              DropdownMenuEntry<int>(
                                value: 4,
                                label: '4',
                              ),
                              DropdownMenuEntry<int>(
                                value: 5,
                                label: '5',
                              ),
                            ],
                          ),
                          const Text(
                            ' ( 秒 )',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10), // 添加間距
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            debugPrint('ElevatedButton was pressed!');
                          },
                          child: const Text('修改'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
