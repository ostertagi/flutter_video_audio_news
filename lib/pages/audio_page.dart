import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/counter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // UI适配库
import 'package:audioplayers/audioplayers.dart'; // audio
import '../service/service_method.dart'; // 网络请求
import '../model/audio_list_model.dart'; // 歌曲列表模型
import '../model/audio_paly_model.dart'; // 歌曲信息模型
import 'dart:ui'; //引入ui库，因为ImageFilter Widget在这个里边。
import './animas/needle_anim.dart'; //  唱针
import './animas/record_anim.dart'; // 圆盘
import 'dart:convert';

class AudioPage extends StatefulWidget {
  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> with TickerProviderStateMixin {
  AudioPlayer audioPlayer = new AudioPlayer();
  List songsResults = []; // 歌曲list数据数组
  AudioPlayModel songModel;
  String picPremium =
      'https://ww1.sinaimg.cn/large/0073sXn7ly1fze9706gdzj30ae0kqmyw'; // 背景图片, 先给一张图片,省的报警告
  double _value = 0; // 进度条初始值
  int index = 0; // 默认加载第一首
  String songURL = ''; // 当前播放url
  bool isPlay = false; // 播放状态 默认未播放
  bool first = false; // 是否是首次点击播放按钮
  String songName = ''; //歌曲名
  String startTime = '00:00'; // 开始时间
  String endTime = '00:00'; // 结束时间

  AnimationController controllerRecord;
  Animation<double> animationRecord;
  Animation<double> animationNeedle;
  AnimationController controllerNeedle;
  final _rotateTween = new Tween<double>(begin: -0.15, end: 0.0);
  final _commonTween = new Tween<double>(begin: 0.0, end: 1.0);

  @override
  void initState() {
    super.initState();
    controllerRecord = new AnimationController(
        duration: const Duration(milliseconds: 15000), vsync: this);
    animationRecord =
        new CurvedAnimation(parent: controllerRecord, curve: Curves.linear);

    controllerNeedle = new AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    animationNeedle =
        new CurvedAnimation(parent: controllerNeedle, curve: Curves.linear);

    animationRecord.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controllerRecord.repeat();
      } else if (status == AnimationStatus.dismissed) {
        controllerRecord.forward();
      }
    });

    // 播放完成
    audioPlayer.onPlayerCompletion.listen((event) {
      _play(index + 1);
    });

    // 时间变化
    audioPlayer.onAudioPositionChanged.listen((Duration p) {
      // print('Current position: $p');
    });

    // 播放状态改变
    audioPlayer.onPlayerStateChanged.listen((AudioPlayerState s) {
      print('Current player state: $s');
    });

    audioPlayer.onDurationChanged.listen((Duration d) {
      print('Max duration: $d');
    });

    _getVideoData();
  }

  @override
  void dispose() {
    controllerNeedle.dispose();
    super.dispose();
  }

  // 获取音频列表数据
  void _getVideoData() async {
    await get('audioList').then((val) {
      var data = json.decode(val.toString());
      AudioListmodel model = AudioListmodel.fromJson(data); // 赋值model
      songsResults.addAll(model.songList);
      // 默认加载第一首
      _play(0);
    });
  }

  // 播放歌曲
  _play(index) async {
    String songId = songsResults[index].songId.toString();
    String formdata = '&songid=' + songId;
    await get('audioInfo', formData: formdata).then((val) {
      var data = json.decode(val.toString());
      songModel = AudioPlayModel.fromJson(data);
      setState(() {
        picPremium = songModel.songinfo.picPremium;
        songURL = songModel.bitrate.fileLink;
        songName = songModel.songinfo.title + '--' + songModel.songinfo.author;
      });
      if (index >= 1) {
        audioPlayer.play(songURL);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CounterBloc _counterBloc = BlocProvider.of<CounterBloc>(context);
    return BlocBuilder(
      bloc: _counterBloc,
      builder: (BuildContext context, Map theme) {
        return Scaffold(
          body: Stack(
            //重叠的Stack Widget，实现重贴
            children: <Widget>[
              // 背景图
              ConstrainedBox(
                  //约束盒子组件，添加额外的限制条件到 child上。
                  constraints: const BoxConstraints.expand(), //限制条件，可扩展的。
                  child: FadeInImage.assetNetwork(
                    placeholder: 'images/pages/LaunchImage.jpeg',
                    image: picPremium,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    fit: BoxFit.cover,
                  )),
              Center(
                child: ClipRect(
                  //裁切长方形
                  child: BackdropFilter(
                    //背景滤镜器
                    filter: ImageFilter.blur(
                        sigmaX: 8.0, sigmaY: 8.0), //图片模糊过滤，横向竖向都设置5.0
                    child: Opacity(
                        //透明控件
                        opacity: 0.6,
                        child: Container(
                          // 容器组件
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          decoration: BoxDecoration(
                              color: Colors.grey), //盒子装饰器，进行装饰，设置颜色为白色
                        )),
                  ),
                ),
              ),
              _audioWidgets(),
            ],
          ),
        );
      },
    );
  }

  // 主体widgets
  Widget _audioWidgets() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height - 90,
      child: SafeArea(
        child: SingleChildScrollView(
          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          child: Column(
            children: <Widget>[
              _nameWidget(),
              _songWidget(),
              _btnsWidget(),
              _progressWidget(),
              _controBtnsWidget()
            ],
          ),
        ),
      ),
    );
  }

  // 歌曲名
  Widget _nameWidget() {
    return Container(
      child: Text(songName, textAlign: TextAlign.center),
    );
  }

  // 唱针
  Widget _styliWidget() {
    return Container(
      padding: EdgeInsets.only(top: 22.0, left: 30),
      width: ScreenUtil().setWidth(180),
      child: PivotTransition(
        turns: _rotateTween.animate(controllerNeedle),
        alignment: FractionalOffset.topLeft,
        child: new Container(
          child: new Image.asset("images/pages/styli.png"),
        ),
      ),
    );
  }

  // 唱盘
  Widget _diskWidget() {
    return Container(
      child: Stack(
        children: <Widget>[
          // Image.asset('images/pages/film.png'),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.white30, width: 6),
                borderRadius: BorderRadius.circular(190),
                image: DecorationImage(
                  image: AssetImage('images/pages/film.png'),
                  fit: BoxFit.cover,
                )),
          ),
          Positioned(
            left: 42,
            top: -57,
            child: Container(
              child: RotateRecord(
                  animation: _commonTween.animate(controllerRecord)),
              margin: EdgeInsets.only(top: 100.0),
            ),
          ),
        ],
      ),
    );
  }

  // 合: 唱盘 + 唱针
  Widget _songWidget() {
    return Container(
      width: ScreenUtil().setWidth(750),
      height: 420,
      padding: EdgeInsets.only(top: 30.0),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _diskWidget(),
          Positioned(
            top: -10,
            child: _styliWidget(),
          )
        ],
      ),
    );
  }

  // 按钮
  Widget _btnsWidget() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.access_time),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.battery_unknown),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.cake),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.date_range),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.email),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  // 进度条
  Widget _progressWidget() {
    return Container(
        child: Row(
      children: <Widget>[
        Text('00:00', style: TextStyle(color: Colors.white)),
        Expanded(
          child: Slider(
            activeColor: Colors.white,
            inactiveColor: Colors.grey,
            value: _value,
            onChanged: (newValue) {
              print('onChanged:$newValue');
              setState(() {
                _value = newValue;
              });
            },
            onChangeStart: (startValue) {
              print('onChangeStart:$startValue');
            },
            onChangeEnd: (endValue) {
              print('onChangeEnd:$endValue');
            },
            semanticFormatterCallback: (newValue) {
              return '${newValue.round()} dollars';
            },
          ),
        ),
        Text('00:00', style: TextStyle(color: Colors.white)),
      ],
    ));
  }

// 控制按钮
  Widget _controBtnsWidget() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          InkWell(
            onTap: () {},
            child: Image.asset(
              'images/pages/single.png',
              fit: BoxFit.fill,
              width: 30,
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                first = false;
              });
            },
            child: Image.asset('images/pages/previous.png',
                fit: BoxFit.fill, width: 30),
          ),
          InkWell(
            onTap: () {
              setState(() {
                isPlay = !isPlay;
              });
              if (isPlay == true && first == false) {
                audioPlayer.play(songURL);
                controllerNeedle.forward();
                controllerRecord.forward();
                setState(() {
                  first = true;
                });
              }

              if (isPlay) {
                // 继续播放
                audioPlayer.resume();
                controllerRecord.forward();
                controllerNeedle.forward();
              } else {
                // 暂停
                audioPlayer.pause();
                controllerRecord.stop(canceled: false);
                controllerNeedle.reverse();
              }
            },
            child: isPlay
                ? Image.asset('images/pages/play.png')
                : Image.asset('images/pages/pause.png'),
          ),
          InkWell(
            onTap: () {
              setState(() {
                first = false;
              });
            },
            child: Image.asset('images/pages/next.png',
                fit: BoxFit.fill, width: 30),
          ),
          InkWell(
            onTap: () {},
            child: Image.asset('images/pages/list.png',
                fit: BoxFit.fill, width: 30),
          ),
        ],
      ),
    );
  }
}
