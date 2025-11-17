import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FavoriteButton extends StatefulWidget {
  final String recipeId;
  final bool initialIsFavorite;
  final Function(bool)? onFavoriteChanged;
  final double size;
  
  const FavoriteButton({
    Key? key,
    required this.recipeId,
    this.initialIsFavorite = false,
    this.onFavoriteChanged,
    this.size = 24,
  }) : super(key: key);

  @override
  _FavoriteButtonState createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> 
    with SingleTickerProviderStateMixin {
  late bool isFavorite;
  final ApiService _apiService = ApiService();
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    isFavorite = widget.initialIsFavorite;
    
    // 初始化動畫
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    final status = await _apiService.checkFavorite(widget.recipeId);
    if (mounted) {
      setState(() => isFavorite = status);
    }
  }

  Future<void> _toggleFavorite() async {
    if (isLoading) return;
    
    setState(() => isLoading = true);

    // 播放動畫
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    Map<String, dynamic> result;
    if (isFavorite) {
      result = await _apiService.removeFavorite(widget.recipeId);
    } else {
      result = await _apiService.addFavorite(widget.recipeId);
    }

    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['success']) {
          isFavorite = !isFavorite;
          widget.onFavoriteChanged?.call(isFavorite);
        }
      });

      // 顯示提示訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result['success'] ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(result['message'])),
            ],
          ),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: isLoading
            ? SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              )
            : Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey[600],
                size: widget.size,
              ),
        onPressed: isLoading ? null : _toggleFavorite,
        tooltip: isFavorite ? '移除最愛' : '加入最愛',
      ),
    );
  }
}