import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); runApp(const NotesApp()); }
const seed = Color(0xFF5267D8);

class Note {
  const Note(this.id, this.title, this.body, this.updated, {this.pinned = false});
  final String id, title, body;
  final DateTime updated;
  final bool pinned;
  Map<String,dynamic> json() => {'id':id,'title':title,'body':body,'updated':updated.toIso8601String(),'pinned':pinned};
  factory Note.from(Map<String,dynamic> m) => Note(m['id'],m['title'],m['body'],DateTime.parse(m['updated']),pinned: m['pinned'] == true);
}

class NotesStore extends ChangeNotifier {
  static const activeKey='simple_notes_active_v2', binKey='simple_notes_bin_v2';
  List<Note> notes=[], bin=[]; bool ready=false;
  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    final savedActive = p.getString(activeKey);
    notes = savedActive == null ? _migrateLegacy(p.getStringList('pamsho_notes_v1') ?? []) : _read(savedActive);
    bin = _read(p.getString(binKey));
    if (savedActive == null && notes.isNotEmpty) await _save();
    _sort(); ready=true; notifyListeners();
  }
  List<Note> _migrateLegacy(List<String> raw) {
    final migrated = <Note>[];
    for (final item in raw) {
      try {
        final parts = Uri.decodeComponent(item).split('|');
        if (parts.length == 4) migrated.add(Note(parts[0], parts[1], parts[2], DateTime.parse(parts[3])));
      } catch (e) { debugPrint('Skipping unreadable legacy note: $e'); }
    }
    return migrated;
  }
  List<Note> _read(String? s) { try { return s==null ? [] : (jsonDecode(s) as List).map((e)=>Note.from(Map<String,dynamic>.from(e))).toList(); } catch(e) { debugPrint('Notes load error: $e'); return []; } }
  void _sort() {
    notes.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updated.compareTo(a.updated);
    });
    bin.sort((a,b)=>b.updated.compareTo(a.updated));
  }
  Future<void> _save() async { final p=await SharedPreferences.getInstance(); await p.setString(activeKey,jsonEncode(notes.map((n)=>n.json()).toList())); await p.setString(binKey,jsonEncode(bin.map((n)=>n.json()).toList())); }
  Future<void> upsert(Note n) async { notes.removeWhere((x)=>x.id==n.id); bin.removeWhere((x)=>x.id==n.id); notes.add(n); _sort(); await _save(); notifyListeners(); }
  Future<void> trash(Note n) async { notes.removeWhere((x)=>x.id==n.id); bin.removeWhere((x)=>x.id==n.id); bin.add(n); _sort(); await _save(); notifyListeners(); }
  Future<void> togglePin(Note n) async {
    final updated = Note(n.id, n.title, n.body, n.updated, pinned: !n.pinned);
    notes.removeWhere((x) => x.id == n.id);
    notes.add(updated);
    _sort();
    await _save();
    notifyListeners();
  }
  Future<void> restore(Note n) async { bin.removeWhere((x)=>x.id==n.id); notes.removeWhere((x)=>x.id==n.id); notes.add(n); _sort(); await _save(); notifyListeners(); }
  Future<void> erase(Note n) async { bin.removeWhere((x)=>x.id==n.id); await _save(); notifyListeners(); }
  Future<void> empty() async { bin.clear(); await _save(); notifyListeners(); }
}

class NotesApp extends StatefulWidget { const NotesApp({super.key}); @override State<NotesApp> createState()=>_NotesAppState(); }
class _NotesAppState extends State<NotesApp> {
  final store=NotesStore(); bool dark=false; Color accent=seed;
  @override void initState(){ super.initState(); store.load(); _settings(); }
  Future<void> _settings() async { final p=await SharedPreferences.getInstance(); if(mounted)setState((){dark=p.getBool('dark')??false; accent=Color(p.getInt('accent')??seed.toARGB32());}); }
  Future<void> setDark(bool v) async { setState(()=>dark=v); final p=await SharedPreferences.getInstance(); await p.setBool('dark',v); }
  Future<void> setAccent(Color c) async { setState(()=>accent=c); final p=await SharedPreferences.getInstance(); await p.setInt('accent',c.toARGB32()); }
  ThemeData theme(Brightness b) { final cs=ColorScheme.fromSeed(seedColor:accent,brightness:b); return ThemeData(useMaterial3:true,colorScheme:cs,scaffoldBackgroundColor:b==Brightness.light?const Color(0xFFF1F3F9):const Color(0xFF111521),appBarTheme:AppBarTheme(backgroundColor:b==Brightness.light?const Color(0xFFF1F3F9):const Color(0xFF111521),foregroundColor:cs.onSurface,elevation:0),cardTheme:CardThemeData(color:b==Brightness.light?Colors.white:const Color(0xFF1E2635),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(19))),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:b==Brightness.light?Colors.white:const Color(0xFF202839),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none))); }
  @override void dispose(){store.dispose();super.dispose();}
  @override Widget build(BuildContext c)=>AnimatedBuilder(animation:store,builder:(c,_)=>
    MaterialApp(debugShowCheckedModeBanner:false,title:'Easy Simple Notes',theme:theme(Brightness.light),darkTheme:theme(Brightness.dark),themeMode:dark?ThemeMode.dark:ThemeMode.light,
      home:Home(store:store,dark:dark,accent:accent,onDark:setDark,onAccent:setAccent)));
}

class Home extends StatefulWidget {
  const Home({super.key,required this.store,required this.dark,required this.accent,required this.onDark,required this.onAccent});
  final NotesStore store; final bool dark; final Color accent; final ValueChanged<bool> onDark; final ValueChanged<Color> onAccent;
  @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home> {
  String query='';
  Future<void> edit([Note? n]) async { await Navigator.push(context,MaterialPageRoute(builder:(_)=>Editor(store:widget.store,note:n))); }
  Future<void> actions(Note n) async {
    final v=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      ListTile(leading:Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined),title:Text(n.pinned ? 'Unpin note' : 'Pin note'),onTap:()=>Navigator.pop(c,'pin')),
      ListTile(leading:const Icon(Icons.edit_outlined),title:const Text('Edit note'),onTap:()=>Navigator.pop(c,'edit')),
      ListTile(leading:Icon(Icons.delete_outline,color:Theme.of(c).colorScheme.error),title:const Text('Move to Bin'),onTap:()=>Navigator.pop(c,'bin')),
      const SizedBox(height:12)])));
    if (v == 'edit') await edit(n);
    if (v == 'pin') {
      await widget.store.togglePin(n);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n.pinned ? 'Note unpinned' : 'Note pinned')),
      );
    }
    if(v=='bin'){await widget.store.trash(n); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Moved to Bin')));}
  }
  @override Widget build(BuildContext c) {
    final t=Theme.of(c), list=widget.store.notes.where((n)=>'${n.title} ${n.body}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(appBar:AppBar(title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Easy Simple Notes',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),Text('Your space for thoughts',style:TextStyle(fontSize:12))]),actions:[
      IconButton(tooltip:'Bin',onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Bin(store:widget.store))),icon:Badge(isLabelVisible:widget.store.bin.isNotEmpty,label:Text('${widget.store.bin.length}'),child:const Icon(Icons.delete_sweep_outlined))),
      IconButton(tooltip:'Settings',onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Settings(dark:widget.dark,accent:widget.accent,onDark:widget.onDark,onAccent:widget.onAccent))),icon:const Icon(Icons.tune_rounded)),const SizedBox(width:5)]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('New note')),
      body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,8,18,90),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(hintText:'Search notes',prefixIcon:Icon(Icons.search))),
        const SizedBox(height:23),Row(children:[const Text('All notes',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),const Spacer(),Text('${list.length} notes',style:TextStyle(color:t.colorScheme.onSurfaceVariant))]),const SizedBox(height:12),
        Expanded(
          child: !widget.store.ready
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sticky_note_2_outlined, size: 58, color: t.colorScheme.primary),
                          const SizedBox(height: 14),
                          Text(query.isEmpty ? 'A fresh page awaits' : 'No notes found',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 7),
                          Text(query.isEmpty ? 'Capture your ideas and reminders.' : 'Try another keyword.',
                              style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
                          if (query.isEmpty)
                            TextButton.icon(
                              onPressed: () => edit(),
                              icon: const Icon(Icons.add),
                              label: const Text('Write your first note'),
                            ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = list[index];
                        return GestureDetector(
                          onLongPress: () => actions(note),
                          child: Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(19),
                              onTap: () => edit(note),
                              child: Padding(
                                padding: const EdgeInsets.all(17),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (note.pinned) ...[
                                          Icon(Icons.push_pin, size: 16, color: t.colorScheme.primary),
                                          const SizedBox(width: 7),
                                        ],
                                        Expanded(
                                          child: Text(
                                            note.title.isEmpty ? 'Untitled note' : note.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        Icon(Icons.more_horiz, color: t.colorScheme.onSurfaceVariant),
                                      ],
                                    ),
                                    if (note.body.isNotEmpty) ...[
                                      const SizedBox(height: 7),
                                      Text(
                                        note.body,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(height: 1.4, color: t.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Text(dateText(note.updated),
                                        style: TextStyle(fontSize: 11, color: t.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]))));
  }
}

class Editor extends StatefulWidget { const Editor({super.key,required this.store,this.note}); final NotesStore store; final Note? note; @override State<Editor> createState()=>_EditorState(); }
class _EditorState extends State<Editor> {
  late final TextEditingController title,body; late final String id; Timer? timer; bool changed=false,saving=false,saved=false;
  @override void initState(){super.initState();id=widget.note?.id??DateTime.now().microsecondsSinceEpoch.toString();title=TextEditingController(text:widget.note?.title??'');body=TextEditingController(text:widget.note?.body??'');title.addListener(schedule);body.addListener(schedule);}
  void schedule(){changed=true;timer?.cancel();if(mounted)setState(()=>saving=true);timer=Timer(const Duration(milliseconds:500),save);}
  Future<void> save() async {if(!changed)return;if(title.text.trim().isEmpty&&body.text.trim().isEmpty){if(mounted)setState(()=>saving=false);return;}try{await widget.store.upsert(Note(id,title.text.trim(),body.text.trim(),DateTime.now(),pinned:widget.note?.pinned??false));changed=false;if(mounted)setState(() { saving=false; saved=true; });}catch(e){debugPrint('Save failed: $e');if(mounted)setState(()=>saving=false);}}
  Future<void> finish() async {timer?.cancel();await save();if(mounted)Navigator.pop(context);}
  @override void dispose(){timer?.cancel();title.dispose();body.dispose();super.dispose();}
  @override Widget build(BuildContext c)=>PopScope(canPop:false,onPopInvokedWithResult:(didPop,result){if(!didPop)finish();},child:Scaffold(appBar:AppBar(leading:IconButton(onPressed:finish,icon:const Icon(Icons.arrow_back)),title:Text(widget.note==null?'New note':'Edit note',style:const TextStyle(fontWeight:FontWeight.w800)),actions:[Padding(padding:const EdgeInsets.only(right:16),child:Center(child:Text(saving?'Saving…':saved?'Saved':'Auto-save',style:TextStyle(fontSize:12,color:Theme.of(c).colorScheme.onSurfaceVariant))))]),body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,20),child:Column(children:[TextField(controller:title,textCapitalization:TextCapitalization.sentences,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800),decoration:const InputDecoration(hintText:'Title',filled:false)),const SizedBox(height:12),Expanded(child:TextField(controller:body,expands:true,minLines:null,maxLines:null,textAlignVertical:TextAlignVertical.top,textCapitalization:TextCapitalization.sentences,style:const TextStyle(fontSize:16,height:1.6),decoration:const InputDecoration(hintText:'Start writing your thoughts…',filled:false)))])))));
}

class Bin extends StatelessWidget {
  const Bin({super.key,required this.store}); final NotesStore store;
  Future<void> emptyBin(BuildContext c) async {final yes=await showDialog<bool>(context:c,builder:(d)=>AlertDialog(title:const Text('Empty Bin?'),content:const Text('These notes will be permanently deleted.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Empty Bin'))]));if(yes==true)await store.empty();}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bin', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (store.bin.isNotEmpty)
            TextButton(onPressed: () => emptyBin(context), child: const Text('Empty')),
        ],
      ),
      body: store.bin.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 56),
                  SizedBox(height: 12),
                  Text('Your Bin is empty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Deleted notes will appear here.'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: store.bin.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = store.bin[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.title.isEmpty ? 'Untitled note' : note.title,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (note.body.isNotEmpty)
                          Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => store.restore(note),
                              icon: const Icon(Icons.restore),
                              label: const Text('Restore'),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Delete permanently',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete permanently?'),
                                    content: const Text('This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dialogContext, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) await store.erase(note);
                              },
                              icon: const Icon(Icons.delete_forever_outlined),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class Settings extends StatelessWidget {
  const Settings({super.key,required this.dark,required this.accent,required this.onDark,required this.onAccent});
  final bool dark; final Color accent; final ValueChanged<bool> onDark; final ValueChanged<Color> onAccent;
  static const colors=[Color(0xFF5267D8),Color(0xFF168C83),Color(0xFF8A55C7),Color(0xFFE07845),Color(0xFFCA5278),Color(0xFF397DAF)];
  @override Widget build(BuildContext c){final t=Theme.of(c);return Scaffold(appBar:AppBar(title:const Text('Settings',style:TextStyle(fontWeight:FontWeight.w800))),body:ListView(padding:const EdgeInsets.all(18),children:[Text('APPEARANCE',style:TextStyle(fontSize:11,letterSpacing:1.2,fontWeight:FontWeight.w800,color:t.colorScheme.onSurfaceVariant)),const SizedBox(height:10),Card(child:SwitchListTile(secondary:Icon(dark?Icons.dark_mode:Icons.light_mode),title:const Text('Dark mode',style:TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(dark?'Dark appearance enabled':'Light appearance enabled'),value:dark,onChanged:onDark)),const SizedBox(height:23),Text('ACCENT COLOR',style:TextStyle(fontSize:11,letterSpacing:1.2,fontWeight:FontWeight.w800,color:t.colorScheme.onSurfaceVariant)),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(18),child:Wrap(spacing:15,runSpacing:15,children:colors.map((color)=>InkWell(customBorder:const CircleBorder(),onTap:()=>onAccent(color),child:Container(width:38,height:38,decoration:BoxDecoration(color:color,shape:BoxShape.circle,border:color.toARGB32()==accent.toARGB32()?Border.all(color:t.colorScheme.onSurface,width:3):null),child:color.toARGB32()==accent.toARGB32()?const Icon(Icons.check,color:Colors.white):null))).toList()))),const SizedBox(height:23),Text('ABOUT',style:TextStyle(fontSize:11,letterSpacing:1.2,fontWeight:FontWeight.w800,color:t.colorScheme.onSurfaceVariant)),const SizedBox(height:10),const Card(child:ListTile(leading:Icon(Icons.sticky_note_2_outlined),title:Text('Easy Simple Notes'),subtitle:Text('A clean, private place for your ideas · Version 1.0'))),const SizedBox(height:12),Text('Notes are stored locally on this device. Clearing app data or uninstalling may remove them.',style:TextStyle(fontSize:12,height:1.5,color:t.colorScheme.onSurfaceVariant))]));}
}
String dateText(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} · ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
