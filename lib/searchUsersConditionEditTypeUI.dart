import 'package:convas/common/UI/commonButtonUI.dart';
import 'package:convas/searchUsersConditionEditTypeProvider.dart';
import 'package:convas/searchUsersProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/UI/commonOthersUI.dart';
import 'common/UI/commonTextUI.dart';


class SearchConditionValueEditType extends ConsumerWidget {
  String displayedItem;
  String databaseItem;
  String value;

  SearchConditionValueEditType({Key? key,
    required this.displayedItem,
    required this.databaseItem,
    required this.value,
  }) : super(key: key);

  bool initialProcessFlg =true;
  List<Widget> checkList = [];

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    checkList=[];
    if(initialProcessFlg){
      initialProcessFlg=false;
      ref.read(searchUsersConditionEditTypeProvider.notifier).initialize(ref, databaseItem, value);
    }

    ref.watch(searchUsersConditionEditTypeProvider).masterMap.forEach((key, value) {
      checkList.add(
          CheckboxListTile(
            title: gray20TextLeft(value),
            value: ref.watch(searchUsersConditionEditTypeProvider).masterBoolMap[key.toString()],
            onChanged: (bool? value) {
              ref.read(searchUsersConditionEditTypeProvider.notifier).setBool(key.toString(),!(value!));
            },
            controlAffinity: ListTileControlAffinity.trailing,
          ));

    });

    return Scaffold(
      appBar: whiteAppbar(displayedItem),
      body: SafeArea(
        child:Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[

            Column(
              mainAxisAlignment: MainAxisAlignment.start,
            children:checkList),
            orangeRoundButton(text: "OK", onPressed: (){
              ref.read(searchUsersProvider.notifier).setConditionByMap(ref,databaseItem,ref.watch(searchUsersConditionEditTypeProvider).masterBoolMap);
              Navigator.pop(context);

            })

          ],
        ),
      ),
    );
  }


}
