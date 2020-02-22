import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import './view_loading.dart';
import './toast.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XTMusic',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: SearchPage(title: 'XTMusic Demo'),
    );
  }
}

class SearchPage extends StatefulWidget {
  SearchPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {

  bool _loading = false;
  var musicList = [];
  var playState = {};
  AudioPlayer audioPlayer;

  @override
  void initState() {
    super.initState();
    initAudioPlayer();
  }

  @override
  void deactivate() async {
    // 释放资源
    await audioPlayer.release();
    super.deactivate();
  }

  /// 初始化实例和设置播放事件监听
  void initAudioPlayer () {
    audioPlayer = AudioPlayer();
    // 总时长
    audioPlayer.onDurationChanged.listen((Duration d) {
      final duration = _formatTime(d.inSeconds);
      setState(() => playState['duration'] = duration);
    });
    // 播放进度
    audioPlayer.onAudioPositionChanged.listen((Duration  p) {
      final position = _formatTime(p.inSeconds);
      setState(() => playState['position'] = position);
    });
    // 播放状态
    audioPlayer.onPlayerStateChanged.listen((AudioPlayerState s) {
      final playing = s == AudioPlayerState.PLAYING;
      setState(() => playState['playing'] = playing);
    });
  }

  /// 将秒格式化为mm:ss的格式
  String _formatTime (seconds) {
    var res = '';
    final min = seconds / 60;
    final sec = seconds % 60;
    res += min < 10 ? '0' + min.toInt().toString() : min.toInt().toString();
    res += ':';
    res += sec < 10 ? '0' + sec.toString() : sec.toString();
    return res;
  }

  /// 创建uuid
  String _uuid () {
    String alphabet = '0123456789abcdef';
    int strlenght = 32; /// 生成的字符串固定长度
    String left = '';
    for (var i = 0; i < strlenght; i++) {
      left = left + alphabet[Random().nextInt(alphabet.length)];
    }
    return left;
  }

  /// 搜索歌曲列表
  void _onSearch(keyword) async {
    if (keyword == '') {
      musicList = [];
      return;
    }
    setState((){
      _loading = true;
    });
    String page = '0';
    String searchUrl = 'http://mobilecdn.kugou.com/api/v3/search/song';
    String searchParams = '?keyword=' + keyword + '&page=' + page + '&pagesize=50&showtype=1';
    print(searchUrl + searchParams);
    Dio dio = new Dio();
    Response response = await dio.get(searchUrl + searchParams);
    final data = jsonDecode(response.data)['data'];
    if (data != null) {
      musicList = data['info'];
    } else {
      Toast.toast(context, msg: '没有找到歌曲', position: ToastPostion.bottom);
    }
    setState((){
      _loading = false;
    });
  }

  /// 获取播放地址并播放
  void _getAndPlay (musicInfo) async {
    // 拼接请求地址
    final hash = musicInfo['hash'];
    final url = 'https://wwwapi.kugou.com/yy/index.php?r=play/getdata&platid=4&mid=917aec0734eebfbc2cda15a8fdf066ee&hash=' + hash;
    // 设置播放状态信息
    playState['id'] = musicInfo["audio_id"];
    playState['fileName'] = musicInfo["filename"];
    playState['duration'] = '00:00';
    playState['position'] = '00:00';
    // 开始请求音乐信息
    Dio dio = new Dio();
    Response response = await dio.get(url);
    final data = jsonDecode(response.data)['data'];
    if (data != null) {
      final playUrl = data['play_url'] == null ? data['play_backup_url'] : data['play_url'];
      if (playUrl != null) {
        playState['url'] = playUrl;
        setState(() {});
        _playOrPause(playUrl);
      } else {
        Toast.toast(context, msg: '播放地址请求失败，可能是没有版权', position: ToastPostion.bottom);
      }
    } else {
      Toast.toast(context, msg: '播放地址请求失败，可能是没有版权', position: ToastPostion.bottom);
    }
  }

  /// 播放或暂停
  void _playOrPause (url) async {
    if (url != null) {
      Toast.toast(context, msg: '正在缓冲歌曲...', position: ToastPostion.bottom);
      int result = await audioPlayer.play(url);
      if (result != 1) {
        Toast.toast(context, msg: '歌曲缓冲失败', position: ToastPostion.bottom);
      }
    } else if (playState['playing'] == true){
      await audioPlayer.pause();
    } else if (playState['url'] != null) {
      await audioPlayer.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: ProgressDialog(
        loading: _loading,
        msg: '正在加载...',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                hintText: '搜索在线歌曲',
                contentPadding: EdgeInsets.all(10.0),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
            ),
            Flexible(
              child: ListView.builder(
                // padding: EdgeInsets.all(10.0),
                itemCount: musicList.length,
                itemBuilder: (context, index) {
                  return FlatButton(
                    padding: EdgeInsets.fromLTRB(10.0, 16.0, 10.0, 16.0),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${index + 1}. ${musicList[index]["filename"]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: playState['id'] == musicList[index]['audio_id'] ? Colors.red : Colors.black,
                        ),
                      ),
                    ),
                    onPressed: () => _getAndPlay(musicList[index]),
                  );
                },
              ),
            ),
            Container(
              height: 60.0,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.all(10.0), //.fromLTRB(10.0, 10.0, 10.0, 10.0),
              decoration: BoxDecoration(
                // border: Border(
                //   top: BorderSide(
                //     width: 2,
                //     color: Colors.black26
                //   )
                // ),
                color: Colors.black12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child:Text(
                    '${playState["fileName"] == null ? "没有正在播放的歌曲" : playState["fileName"]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    )
                  ),
                  Text(playState['duration'] == null ? '00:00 / 00:00 ' : playState['position'] + ' / ' + playState['duration']),
                  RaisedButton(
                    color: Colors.red,
                    textColor: Colors.white,
                    shape: CircleBorder(side: BorderSide(color: Colors.red)),
                    padding: EdgeInsets.all(0),
                    child: Icon(playState['playing'] == true ? Icons.pause : Icons.play_arrow), // Icons.play_arrow
                    onPressed: () => _playOrPause(null),
                  ),
                ]
              ),
            )
          ],
        ),
      ),
    );
  }
}
