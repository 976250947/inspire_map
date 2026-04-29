"""
社交关系模型：关注 / 粉丝 / 点赞 / 评论
"""
from sqlalchemy import Column, String, Text, ForeignKey, UniqueConstraint

from app.models.base import Base


class UserFollow(Base):
    """用户关注关系表"""

    # 关注者
    follower_id = Column(
        String(36),
        ForeignKey("user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="关注者用户ID"
    )
    # 被关注者
    following_id = Column(
        String(36),
        ForeignKey("user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="被关注者用户ID"
    )

    # 唯一约束：不能重复关注同一个人
    __table_args__ = (
        UniqueConstraint("follower_id", "following_id", name="uq_follow_pair"),
    )


class UserLike(Base):
    """用户点赞关系表"""

    user_id = Column(
        String(36),
        ForeignKey("user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="点赞用户ID"
    )
    post_id = Column(
        String(36),
        ForeignKey("userpost.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="被点赞动态ID"
    )

    # 唯一约束：同一用户不能重复点赞同一条动态
    __table_args__ = (
        UniqueConstraint("user_id", "post_id", name="uq_like_pair"),
    )


class UserComment(Base):
    """用户评论表"""

    user_id = Column(
        String(36),
        ForeignKey("user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="评论用户ID"
    )
    post_id = Column(
        String(36),
        ForeignKey("userpost.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="评论所属动态ID"
    )
    content = Column(
        Text,
        nullable=False,
        comment="评论内容"
    )
    # 支持回复（可选，为 None 表示顶级评论）
    parent_id = Column(
        String(36),
        ForeignKey("usercomment.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
        comment="父评论ID（回复）"
    )
