import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Это важно для инициализации Flutter перед использованием SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SavingsJarApp());
}

/// Основное приложение, устанавливает тему и начальный экран
class SavingsJarApp extends StatelessWidget {
  const SavingsJarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Копилка',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.tealAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.purpleAccent,
          surface: Color(0xFF121212),
          background: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            color: Colors.white70,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SavingsJarScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Основной экран приложения с копилкой
class SavingsJarScreen extends StatefulWidget {
  const SavingsJarScreen({super.key});

  @override
  State<SavingsJarScreen> createState() => _SavingsJarScreenState();
}

class _SavingsJarScreenState extends State<SavingsJarScreen>
    with SingleTickerProviderStateMixin {
  // Контроллеры для ввода текста
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _addAmountController = TextEditingController();

  // Значения для отслеживания накоплений
  double _goalAmount = 0.0;
  double _currentAmount = 0.0;
  double _previousAmount = 0.0; // Для анимации
  
  // Флаг для отслеживания, установлена ли цель
  bool _isGoalSet = false;
  
  // Флаг для отслеживания загрузки данных
  bool _isLoading = true;

  // Контроллер анимации для наполнения кувшина
  late AnimationController _animationController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    
    // Инициализация контроллера анимации
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Анимация с замедлением в конце
    _fillAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    // Слушатель для обновления UI во время анимации
    _animationController.addListener(() {
      setState(() {});
    });
    
    // Загрузка сохраненных данных
    _loadSavedData();
  }

  // Метод для загрузки сохраненных данных
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final savedGoal = prefs.getDouble('goalAmount');
      final savedCurrent = prefs.getDouble('currentAmount');
      
      if (savedGoal != null && savedCurrent != null) {
        setState(() {
          _goalAmount = savedGoal;
          _currentAmount = savedCurrent;
          _previousAmount = savedCurrent;
          _isGoalSet = savedGoal > 0;
          _isLoading = false;
        });
        
        print('Данные загружены: цель=$_goalAmount, текущая сумма=$_currentAmount');
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Сохраненные данные не найдены');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Ошибка при загрузке данных: $e');
    }
  }
  
  // Метод для сохранения данных
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setDouble('goalAmount', _goalAmount);
      await prefs.setDouble('currentAmount', _currentAmount);
      
      print('Данные сохранены: цель=$_goalAmount, текущая сумма=$_currentAmount');
    } catch (e) {
      print('Ошибка при сохранении данных: $e');
    }
  }

  @override
  void dispose() {
    // Освобождение ресурсов
    _goalController.dispose();
    _currentController.dispose();
    _addAmountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Метод для установки цели и начальной суммы
  void _setGoal() {
    // Проверка на корректность ввода
    if (_goalController.text.isEmpty || _currentController.text.isEmpty) {
      _showErrorSnackBar('Пожалуйста, введите цель и текущую сумму');
      return;
    }

    try {
      final goal = double.parse(_goalController.text);
      final current = double.parse(_currentController.text);
      
      if (goal <= 0) {
        _showErrorSnackBar('Цель должна быть больше нуля');
        return;
      }
      
      if (current < 0) {
        _showErrorSnackBar('Текущая сумма не может быть отрицательной');
        return;
      }
      
      if (current > goal) {
        _showErrorSnackBar('Текущая сумма не может быть больше цели');
        return;
      }

      setState(() {
        _goalAmount = goal;
        _currentAmount = current;
        _previousAmount = current;
        _isGoalSet = true;
      });
      
      // Сохраняем данные
      _saveData();
      
      // Сброс полей ввода
      _goalController.clear();
      _currentController.clear();
      
    } catch (e) {
      _showErrorSnackBar('Пожалуйста, введите корректные числа');
    }
  }

  // Метод для добавления суммы к накоплениям
  void _addAmount() {
    if (_addAmountController.text.isEmpty) {
      _showErrorSnackBar('Пожалуйста, введите сумму для добавления');
      return;
    }

    try {
      final amount = double.parse(_addAmountController.text);
      
      if (amount <= 0) {
        _showErrorSnackBar('Сумма должна быть больше нуля');
        return;
      }
      
      // Сохраняем предыдущую сумму для анимации
      _previousAmount = _currentAmount;
      
      // Вычисляем новую сумму, но не больше цели
      final newAmount = math.min(_currentAmount + amount, _goalAmount);
      
      // Настраиваем анимацию от предыдущего до нового значения
      _animationController.reset();
      _animationController.forward();
      
      setState(() {
        _currentAmount = newAmount;
      });
      
      // Сохраняем данные
      _saveData();
      
      // Сброс поля ввода
      _addAmountController.clear();
      
    } catch (e) {
      _showErrorSnackBar('Пожалуйста, введите корректное число');
    }
  }

  // Метод для отображения сообщения об ошибке
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Метод для сброса всех данных
  void _resetGoal() {
    setState(() {
      _isGoalSet = false;
      _goalAmount = 0.0;
      _currentAmount = 0.0;
      _previousAmount = 0.0;
      _animationController.reset();
    });
    
    // Сохраняем сброшенные данные
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    // Показываем индикатор загрузки, пока данные загружаются
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Копилка'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isGoalSet)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetGoal,
              tooltip: 'Сбросить цель',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isGoalSet ? _buildSavingsJarView() : _buildGoalSetupView(),
      ),
    );
  }

  // Виджет для настройки цели
  Widget _buildGoalSetupView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.savings_outlined,
              size: 80,
              color: Colors.tealAccent,
            ),
            const SizedBox(height: 24),
            Text(
              'Установите вашу финансовую цель',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Целевая сумма',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Текущая сумма накоплений',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _setGoal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Начать копить'),
            ),
          ],
        ),
      ),
    );
  }

  // Виджет для отображения кувшина с накоплениями
  Widget _buildSavingsJarView() {
    // Вычисляем текущий прогресс для анимации
    final animatedFillPercentage = _previousAmount + 
        (_currentAmount - _previousAmount) * _fillAnimation.value;
    final fillPercentage = animatedFillPercentage / _goalAmount;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Отображение текущей суммы и цели
          Text(
            '${_currentAmount.toStringAsFixed(2)} / ${_goalAmount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          
          // Прогресс в процентах
          Text(
            '${(fillPercentage * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          
          // Кувшин с накоплениями
          SizedBox(
            height: 300,
            width: 200,
            child: CustomPaint(
              painter: JarPainter(fillPercentage: fillPercentage),
            ),
          ),
          const SizedBox(height: 32),
          
          // Поле для добавления суммы
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Добавить сумму',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.add_circle_outline),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _addAmount,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Добавить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Кастомный виджет для отрисовки кувшина
class JarPainter extends CustomPainter {
  final double fillPercentage;
  
  JarPainter({required this.fillPercentage});
  
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Определяем размеры кувшина
    final jarWidth = width * 0.8;
    final jarHeight = height * 0.85;
    final jarLeft = (width - jarWidth) / 2;
    final jarTop = height * 0.1;
    final jarBottom = jarTop + jarHeight;
    
    // Определяем размеры горлышка кувшина
    final neckWidth = jarWidth * 0.5;
    final neckHeight = jarHeight * 0.15;
    final neckLeft = jarLeft + (jarWidth - neckWidth) / 2;
    
    // Создаем путь для кувшина
    final jarPath = Path();
    
    // Горлышко кувшина
    jarPath.moveTo(neckLeft, jarTop);
    jarPath.lineTo(neckLeft + neckWidth, jarTop);
    jarPath.lineTo(neckLeft + neckWidth, jarTop + neckHeight);
    
    // Правая сторона кувшина
    jarPath.lineTo(jarLeft + jarWidth, jarTop + neckHeight);
    jarPath.lineTo(jarLeft + jarWidth, jarBottom);
    
    // Дно кувшина
    jarPath.lineTo(jarLeft, jarBottom);
    
    // Левая сторона кувшина
    jarPath.lineTo(jarLeft, jarTop + neckHeight);
    jarPath.lineTo(neckLeft, jarTop + neckHeight);
    
    // Замыкаем путь
    jarPath.close();
    
    // Рисуем контур кувшина
    final jarPaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(jarPath, jarPaint);
    
    // Создаем путь для заполнения кувшина
    final fillPath = Path();
    
    // Вычисляем высоту заполнения
    final fillHeight = jarHeight * fillPercentage;
    final fillTop = jarBottom - fillHeight;
    
    // Если заполнение достигает горлышка, учитываем его форму
    if (fillTop <= jarTop + neckHeight) {
      // Заполнение включает горлышко
      final neckFillTop = math.max(fillTop, jarTop);
      
      // Левая сторона горлышка
      fillPath.moveTo(neckLeft, neckFillTop);
      
      if (neckFillTop == jarTop) {
        // Верх горлышка
        fillPath.lineTo(neckLeft + neckWidth, jarTop);
      }
      
      // Правая сторона горлышка
      fillPath.lineTo(neckLeft + neckWidth, jarTop + neckHeight);
      
      // Правая сторона кувшина
      fillPath.lineTo(jarLeft + jarWidth, jarTop + neckHeight);
      fillPath.lineTo(jarLeft + jarWidth, jarBottom);
      
      // Дно кувшина
      fillPath.lineTo(jarLeft, jarBottom);
      
      // Левая сторона кувшина
      fillPath.lineTo(jarLeft, jarTop + neckHeight);
      fillPath.lineTo(neckLeft, jarTop + neckHeight);
      
      // Замыкаем путь
      if (neckFillTop > jarTop) {
        fillPath.lineTo(neckLeft, neckFillTop);
      }
    } else {
      // Заполнение только в основной части кувшина
      fillPath.moveTo(jarLeft, fillTop);
      fillPath.lineTo(jarLeft + jarWidth, fillTop);
      fillPath.lineTo(jarLeft + jarWidth, jarBottom);
      fillPath.lineTo(jarLeft, jarBottom);
      fillPath.close();
    }
    
    // Градиент для заполнения
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.tealAccent.withOpacity(0.7),
          Colors.tealAccent.withOpacity(0.9),
        ],
      ).createShader(Rect.fromLTWH(jarLeft, fillTop, jarWidth, jarBottom - fillTop));
    
    // Рисуем заполнение
    canvas.drawPath(fillPath, fillPaint);
    
    // Добавляем блики для эффекта стекла
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Блик слева
    final leftHighlight = Path();
    leftHighlight.moveTo(jarLeft + jarWidth * 0.2, jarTop + neckHeight + jarHeight * 0.1);
    leftHighlight.quadraticBezierTo(
      jarLeft + jarWidth * 0.1, 
      jarTop + neckHeight + jarHeight * 0.4,
      jarLeft + jarWidth * 0.2, 
      jarBottom - jarHeight * 0.1
    );
    canvas.drawPath(leftHighlight, highlightPaint);
    
    // Блик справа
    final rightHighlight = Path();
    rightHighlight.moveTo(jarLeft + jarWidth * 0.8, jarTop + neckHeight + jarHeight * 0.1);
    rightHighlight.quadraticBezierTo(
      jarLeft + jarWidth * 0.9, 
      jarTop + neckHeight + jarHeight * 0.4,
      jarLeft + jarWidth * 0.8, 
      jarBottom - jarHeight * 0.1
    );
    canvas.drawPath(rightHighlight, highlightPaint);
  }
  
  @override
  bool shouldRepaint(covariant JarPainter oldDelegate) {
    return oldDelegate.fillPercentage != fillPercentage;
  }
}
